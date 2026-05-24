class Visual < ApplicationRecord
  delegated_type :kind, types: %w[
    Visual::Diagram
    Visual::Timeline
    Visual::Comparison
  ], dependent: :destroy

  belongs_to :study_guide

  def self.kind_class_for(slug)
    kind_types.find { it.demodulize.underscore == slug.to_s }&.constantize
  end
end
