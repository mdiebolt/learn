module RenderPartialsWithoutNamespace
  extend ActiveSupport::Concern

  included do
    before_action { view_context.prefix_partial_path_with_controller_namespace = false }
  end
end
