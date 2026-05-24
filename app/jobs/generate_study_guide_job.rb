class GenerateStudyGuideJob < ApplicationJob
  queue_as :default

  def perform(chapter, user, client: Anthropic::Claude.new)
    raw_response = client.complete(prompt: build_prompt(chapter), system: system_prompt)
    StudyGuide.create_from_ai_payload!(chapter:, user:, raw_response:, model: client.model)
  end

  private

  def system_prompt
    <<~PROMPT
      You author interactive study guides from audiobook chapter transcripts.
      Pull out the most important concepts and convert them into quiz cards and supporting visuals.
      Respond with raw JSON only — no prose, no markdown fences.

      Output schema:
      { "topics": [
          { "type": "visual", "kind": "<#{Visual.kind_types.map { it.demodulize.underscore }.join("|")}>", "caption": "...", "attributes": { ... } },
          { "type": "card",   "kind": "<#{Card.kind_types.map { it.demodulize.underscore }.join("|")}>",
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
end
