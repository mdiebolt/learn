class ApplicationController < ActionController::Base
  include Authentication

  default_form_builder UiFormBuilder

  allow_browser versions: :modern

  stale_when_importmap_changes
end
