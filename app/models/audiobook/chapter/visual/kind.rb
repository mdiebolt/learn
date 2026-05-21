module Audiobook::Chapter::Visual::Kind
  extend ActiveSupport::Concern

  included do
    has_one :visual, as: :kind,
      class_name: "Audiobook::Chapter::Visual",
      touch: true
  end
end
