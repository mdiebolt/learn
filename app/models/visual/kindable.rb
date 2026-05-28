module Visual::Kindable
  extend ActiveSupport::Concern

  included do
    delegated_type :kind, types: %w[
      Visual::Diagram
      Visual::Timeline
      Visual::Comparison
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
