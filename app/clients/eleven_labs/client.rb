module ElevenLabs
  class Client
    API_BASE = "https://api.elevenlabs.io/v1"

    def initialize(api_key: TextToSpeech.api_key, voice_id: TextToSpeech.voice_id)
      @api_key = api_key
      @voice_id = voice_id
    end

    def generate_speech_with_timestamps(text)
      response = connection.post("text-to-speech/#{@voice_id}/with-timestamps") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = {
          text: text,
          model_id: "eleven_multilingual_v2",
          output_format: "mp3_44100_128"
        }.to_json
      end

      handle_response(response)
    end

    private

    def connection
      @connection ||= Faraday.new(url: API_BASE) do |f|
        f.headers["xi-api-key"] = @api_key
        f.options.timeout = 300
        f.options.open_timeout = 10
        f.adapter Faraday.default_adapter
      end
    end

    def handle_response(response)
      case response.status
      when 200
        JSON.parse(response.body)
      when 401
        raise AuthenticationError, "Invalid API key"
      when 429
        raise RateLimitError, "Rate limit exceeded"
      else
        raise ApiError, "API error: #{response.status} - #{response.body}"
      end
    end

    class ApiError < StandardError; end
    class AuthenticationError < ApiError; end
    class RateLimitError < ApiError; end
  end
end
