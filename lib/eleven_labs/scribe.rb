require "faraday"
require "faraday/multipart"
require "json"

module ElevenLabs
  class Scribe
    API_URL = "https://api.elevenlabs.io/v1/speech-to-text"
    MODEL_ID = "scribe_v1"

    def initialize(api_key: Rails.application.credentials.dig(:eleven_labs, :api_key))
      @api_key = api_key
    end

    # Transcribe an audio file. Returns the parsed Scribe response — a hash with
    # a "words" array where each entry has text/start/end/type ("word",
    # "spacing", or "audio_event"). Caller is responsible for filtering.
    def transcribe(file_path)
      raise "missing api key" unless @api_key

      response = connection.post(API_URL) do |req|
        req.headers["xi-api-key"] = @api_key
        req.body = {
          file: Faraday::Multipart::FilePart.new(file_path, "audio/mpeg"),
          model_id: MODEL_ID
        }
      end

      raise Error, "Scribe #{response.status}: #{response.body}" unless response.success?
      JSON.parse(response.body)
    end

    private

    def connection
      @connection ||= Faraday.new do |f|
        f.request :multipart
        f.options.timeout = 1800
        f.options.open_timeout = 30
        f.adapter Faraday.default_adapter
      end
    end

    class Error < StandardError; end
  end
end
