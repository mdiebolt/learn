class PreferencesController < ApplicationController
  def update
    if Current.user.update(wpm: params[:wpm])
      head :no_content
    else
      head :unprocessable_entity
    end
  end
end
