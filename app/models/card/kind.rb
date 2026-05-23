module Card::Kind
  extend ActiveSupport::Concern

  included do
    has_one :card, as: :kind, touch: true
  end

  def to_answer_partial_path
    "#{to_partial_path.rpartition('/').first}/answer"
  end
end
