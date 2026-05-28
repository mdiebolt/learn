module Card::Kindable
  extend ActiveSupport::Concern

  included do
    delegated_type :kind, types: %w[
      Card::MultipleChoice
      Card::Cloze
      Card::FreeResponse
      Card::Ordering
      Card::Matching
    ], dependent: :destroy

    delegate :glyph, to: :kind
  end

  class_methods do
    def build_kind(slug, attributes = {})
      type = kind_types.find { it.demodulize.underscore == slug.to_s }
      type&.constantize&.create!(attributes)
    end
  end

  def name
    kind.model_name.element.titleize
  end
end
