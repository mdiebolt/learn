module RenderPartialsWithoutNamespace
  extend ActiveSupport::Concern

  private

  def view_context
    super.tap { |view| view.prefix_partial_path_with_controller_namespace = false }
  end
end
