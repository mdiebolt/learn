class StudyGuide < ApplicationRecord
  PROMPT_VERSION = "v1"

  EmptyGeneration = Class.new(StandardError)

  belongs_to :user
  belongs_to :chapter

  has_many :topics, -> { order(:position) }, dependent: :destroy
  has_many :cards, dependent: :nullify
  has_many :visuals, dependent: :destroy

  after_create_commit :broadcast_ready, :broadcast_control

  class << self
    def create_from_ai_payload!(chapter:, user:, raw_response:, model:, prompt_version: PROMPT_VERSION)
      transaction do
        guide = create!(user: user, chapter: chapter, model: model, prompt_version: prompt_version)
        parse_payload(raw_response).fetch("topics", []).each { guide.append_from_ai(it) }
        raise EmptyGeneration, "AI returned no usable topics for chapter #{chapter.id}" if guide.topics.empty?
        guide
      end
    end

    private

    def parse_payload(raw)
      text = raw.to_s.strip.sub(/\A```(?:json)?/, "").sub(/```\z/, "").strip
      JSON.parse(text)
    end
  end

  def append_from_ai(raw)
    record = build_topical(raw)
    topics.create!(topical: record, position: topics.size) if record
  end

  private

  def build_topical(raw)
    self.class.transaction(requires_new: true) do
      case raw["type"]
      when "card"   then build_card(raw)
      when "visual" then build_visual(raw)
      end
    end
  rescue ActiveRecord::RecordInvalid, KeyError => e
    Rails.logger.warn("[#{self.class.name}] dropping topic #{raw.inspect}: #{e.message}")
    nil
  end

  def build_card(raw)
    kind_class = Card.kind_class_for(raw["kind"]) or return nil
    kind = kind_class.create!(raw.fetch("attributes", {}))
    cards.create!(
      user: user,
      chapter: chapter,
      concept_title: raw["concept_title"],
      source_excerpt: raw["source_excerpt"],
      kind: kind,
      due: Time.current
    )
  end

  def build_visual(raw)
    kind_class = Visual.kind_class_for(raw["kind"]) or return nil
    kind = kind_class.create!(raw.fetch("attributes", {}))
    visuals.create!(kind: kind, caption: raw["caption"])
  end

  def broadcast_ready
    broadcast_replace_to(
      [ chapter, :study_guide ],
      target: ActionView::RecordIdentifier.dom_id(chapter, :study_guide),
      partial: "chapter/study_guides/ready",
      locals: { audiobook: chapter.audiobook, chapter: chapter, study_guide: self }
    )
  end

  def broadcast_control
    broadcast_replace_to(
      [ chapter, :study_guide_control ],
      target: ActionView::RecordIdentifier.dom_id(chapter, :study_guide_control),
      partial: "chapter/study_guides/control",
      locals: { audiobook: chapter.audiobook, chapter: chapter, study_guide: self }
    )
  end
end
