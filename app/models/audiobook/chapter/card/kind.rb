module Audiobook::Chapter::Card::Kind
  extend ActiveSupport::Concern

  included do
    has_one :card, as: :kind,
      class_name: "Audiobook::Chapter::Card",
      touch: true
  end
end
