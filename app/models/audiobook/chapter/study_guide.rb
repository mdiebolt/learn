class Audiobook::Chapter::StudyGuide < ApplicationRecord
  PROMPT_VERSION = "v1"

  EmptyGeneration = Class.new(StandardError)

  belongs_to :user
  belongs_to :audiobook_chapter, class_name: "Audiobook::Chapter"

  has_many :items, -> { order(:position) },
    class_name: "Audiobook::Chapter::StudyGuide::Item",
    foreign_key: :audiobook_chapter_study_guide_id, dependent: :destroy
  has_many :cards, class_name: "Audiobook::Chapter::Card",
    foreign_key: :audiobook_chapter_study_guide_id, dependent: :nullify
  has_many :visuals, class_name: "Audiobook::Chapter::Visual",
    foreign_key: :audiobook_chapter_study_guide_id, dependent: :destroy

  after_create_commit :broadcast_ready, :broadcast_control

  class << self
    def create_from_ai_payload!(chapter:, user:, raw_response:, model:, prompt_version: PROMPT_VERSION)
      transaction do
        guide = create!(user: user, audiobook_chapter: chapter, model: model, prompt_version: prompt_version)
        parse_payload(raw_response).fetch("items", []).each { |raw| guide.append_from_ai(raw) }
        raise EmptyGeneration, "AI returned no usable items for chapter #{chapter.id}" if guide.items.empty?
        guide
      end
    end

    private

    def parse_payload(raw)
      text = raw.to_s.strip.sub(/\A```(?:json)?/, "").sub(/```\z/, "").strip
      JSON.parse(text)
    end
  end

  def chapter
    audiobook_chapter
  end

  def append_from_ai(raw)
    record = build_itemable(raw)
    items.create!(itemable: record, position: items.size) if record
  end

  private

  def build_itemable(raw)
    self.class.transaction(requires_new: true) do
      case raw["type"]
      when "card"   then build_card(raw)
      when "visual" then build_visual(raw)
      end
    end
  rescue ActiveRecord::RecordInvalid, KeyError => e
    Rails.logger.warn("[#{self.class.name}] dropping item #{raw.inspect}: #{e.message}")
    nil
  end

  def build_card(raw)
    kind_class = Audiobook::Chapter::Card.kind_class_for(raw["kind"]) or return nil
    kind = kind_class.create!(raw.fetch("attributes", {}))
    cards.create!(
      user: user,
      audiobook_chapter: audiobook_chapter,
      concept_title: raw["concept_title"],
      source_excerpt: raw["source_excerpt"],
      kind: kind,
      due: Time.current
    )
  end

  def build_visual(raw)
    kind_class = Audiobook::Chapter::Visual.kind_class_for(raw["kind"]) or return nil
    kind = kind_class.create!(raw.fetch("attributes", {}))
    visuals.create!(kind: kind, caption: raw["caption"])
  end

  def broadcast_ready
    broadcast_replace_to(
      [ audiobook_chapter, :study_guide ],
      target: ActionView::RecordIdentifier.dom_id(audiobook_chapter, :study_guide),
      partial: "audiobook/chapter/study_guides/ready",
      locals: { audiobook: audiobook_chapter.audiobook, chapter: audiobook_chapter, study_guide: self }
    )
  end

  def broadcast_control
    broadcast_replace_to(
      [ audiobook_chapter, :study_guide_control ],
      target: ActionView::RecordIdentifier.dom_id(audiobook_chapter, :study_guide_control),
      partial: "audiobook/chapter/study_guides/control",
      locals: { audiobook: audiobook_chapter.audiobook, chapter: audiobook_chapter, study_guide: self }
    )
  end
end
