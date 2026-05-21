module Audiobook::Chapter::Card::Kind
  extend ActiveSupport::Concern

  included do
    has_one :card, as: :kind,
      class_name: "Audiobook::Chapter::Card",
      touch: true
  end

  def to_answer_partial_path
    "#{to_partial_path.rpartition('/').first}/answer"
  end
end
