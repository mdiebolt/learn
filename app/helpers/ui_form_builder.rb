# The application's default form builder (wired in via
# `ApplicationController.default_form_builder`). It only overrides the
# standard Rails field methods to inject the project's `ui-*` classes, so
# views call `form.email_field` / `form.label` exactly as they would with
# the stock builder — swapping this out for another builder needs no view
# changes, the inputs just lose their default styling.
class UiFormBuilder < ActionView::Helpers::FormBuilder
  FIELD_CLASSES = {
    text_field: "ui-input ui-input--text",
    email_field: "ui-input ui-input--email",
    password_field: "ui-input ui-input--password",
    file_field: "ui-input ui-input--file"
  }.freeze

  FIELD_CLASSES.each do |field_method, default_class|
    define_method(field_method) do |attribute, options = {}|
      super(attribute, prepend_class(options, default_class))
    end
  end

  def label(attribute, text = nil, options = nil, &block)
    text, options = nil, text if text.is_a?(Hash)
    super(attribute, text, prepend_class(options || {}, "ui-label"), &block)
  end

  def submit(value = nil, options = {})
    value, options = nil, value if value.is_a?(Hash)
    super(value, prepend_class(options, "ui-button ui-button--accent"))
  end

  private

  def prepend_class(options, default_class)
    options.to_h.merge(class: @template.token_list(default_class, options[:class]))
  end
end
