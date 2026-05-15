class PreferencesController < ApplicationController
  def update
    if Current.user.update(preference_params)
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  private

  def preference_params
    params.permit(:wpm, :audio_offset_ms)
  end
end
