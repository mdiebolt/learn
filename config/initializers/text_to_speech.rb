module TextToSpeech
  mattr_accessor :provider
  mattr_accessor :api_key
  mattr_accessor :voice_id

  self.provider = :eleven_labs
  self.api_key = Rails.application.credentials.dig(:eleven_labs, :api_key)

  self.voice_id = "21m00Tcm4TlvDq8ikWAM"
end
