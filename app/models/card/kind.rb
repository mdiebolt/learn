module Card::Kind
  extend ActiveSupport::Concern

  included do
    has_one :card, as: :kind, touch: true
  end
end
