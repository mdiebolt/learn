module Visual::Kind
  extend ActiveSupport::Concern

  included do
    has_one :visual, as: :kind, touch: true
  end
end
