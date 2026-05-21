class Audiobook::Chapter::StudyGuide::GenerateJob < ApplicationJob
  PROMPT_VERSION = "v1"

  queue_as :default

  def perform(chapter, user, client: Anthropic::Claude.new)
    prompt = build_prompt(chapter)
    payload = parse_response(client.complete(prompt: prompt, system: system_prompt))
    persist!(chapter: chapter, user: user, items: payload.fetch("items", []), model: client.model)
  end

  private

  def system_prompt
    <<~PROMPT
      You author interactive study guides from audiobook chapter transcripts.
      Pull out the most important concepts and convert them into quiz cards and supporting visuals.
      Respond with raw JSON only — no prose, no markdown fences.

      Output schema:
      { "items": [
          { "type": "visual", "kind": "<#{Audiobook::Chapter::Visual.kind_types.map { |t| t.demodulize.underscore }.join("|")}>", "caption": "...", "attributes": { ... } },
          { "type": "card",   "kind": "<#{Audiobook::Chapter::Card.kind_types.map { |t| t.demodulize.underscore }.join("|")}>",
            "concept_title": "...", "source_excerpt": "...", "attributes": { ... } }
        ] }

      Card kinds and their `attributes`:
        - multiple_choice: { question, options (array), correct_index (int), rationale }
        - cloze:           { text (uses {{0}}, {{1}} blank markers), answers (array) }
        - free_response:   { question, reference_answer, rubric }
        - ordering:        { prompt, items (canonical order) }
        - matching:        { prompt, pairs ([{ "left": "...", "right": "..." }]) }

      Visual kinds and their `attributes`:
        - diagram:    { nodes ([{id,label}]), edges ([{from,to,label}]) }
        - timeline:   { events ([{when,label}]) }
        - comparison: { columns (array of strings), rows (array of objects keyed by column) }
    PROMPT
  end

  def build_prompt(chapter)
    transcript = chapter.words.order(:position).pluck(:text).join(" ")
    <<~PROMPT
      Audiobook: #{chapter.audiobook.title}
      Chapter: #{chapter.title}

      Transcript:
      #{transcript}
    PROMPT
  end

  def parse_response(raw)
    text = raw.to_s.strip
    text = text.sub(/\A```(?:json)?/, "").sub(/```\z/, "").strip
    JSON.parse(text)
  end

  def persist!(chapter:, user:, items:, model:)
    Audiobook::Chapter::StudyGuide.transaction do
      guide = Audiobook::Chapter::StudyGuide.create!(
        user: user, audiobook_chapter: chapter, model: model, prompt_version: PROMPT_VERSION
      )

      position = 0
      items.each do |item|
        record = build_item(item, chapter: chapter, user: user, guide: guide)
        next unless record
        guide.items.create!(itemable: record, position: position)
        position += 1
      end

      if guide.items.empty?
        guide.destroy
        raise EmptyGenerationError, "AI returned no usable items for chapter #{chapter.id}"
      end

      broadcast_completion(guide)
      guide
    end
  end

  def build_item(item, chapter:, user:, guide:)
    Audiobook::Chapter::StudyGuide.transaction(requires_new: true) do
      case item["type"]
      when "card"   then build_card(item, chapter: chapter, user: user, guide: guide)
      when "visual" then build_visual(item, guide: guide)
      end
    end
  rescue ActiveRecord::RecordInvalid, KeyError => e
    Rails.logger.warn("[#{self.class.name}] dropping item #{item.inspect}: #{e.message}")
    nil
  end

  def build_card(item, chapter:, user:, guide:)
    kind_class = CARD_KINDS[item["kind"]] or return nil
    kind = kind_class.create!(item.fetch("attributes", {}))
    chapter.cards.create!(
      user: user,
      study_guide: guide,
      concept_title: item["concept_title"],
      source_excerpt: item["source_excerpt"],
      kind: kind,
      due: Time.current
    )
  end

  def build_visual(item, guide:)
    kind_class = VISUAL_KINDS[item["kind"]] or return nil
    kind = kind_class.create!(item.fetch("attributes", {}))
    guide.visuals.create!(kind: kind, caption: item["caption"])
  end

  def broadcast_completion(guide)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ guide.audiobook_chapter, :study_guide ],
      target: ActionView::RecordIdentifier.dom_id(guide.audiobook_chapter, :study_guide),
      partial: "audiobook/chapter/study_guides/ready",
      locals: { audiobook: guide.audiobook_chapter.audiobook, chapter: guide.audiobook_chapter, study_guide: guide }
    )
  end

  CARD_KINDS = Audiobook::Chapter::Card.kind_types.index_by { |t| t.demodulize.underscore }
    .transform_values(&:constantize).freeze
  VISUAL_KINDS = Audiobook::Chapter::Visual.kind_types.index_by { |t| t.demodulize.underscore }
    .transform_values(&:constantize).freeze

  class EmptyGenerationError < StandardError; end
end
