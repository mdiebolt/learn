require "faraday"
require "json"

module Anthropic
  class Claude
    API_URL = "https://api.anthropic.com/v1/messages"
    API_VERSION = "2023-06-01"
    DEFAULT_MODEL = "claude-opus-4-7"

    def initialize(api_key: Rails.application.credentials.dig(:anthropic, :api_key), model: DEFAULT_MODEL)
      @api_key = api_key
      @model = model
    end

    def model
      @model
    end

    # Sends a single user message and returns the model's text response.
    def complete(prompt:, system: nil, max_tokens: 8192)
      raise "missing api key" unless @api_key

      body = { model: @model, max_tokens: max_tokens, messages: [ { role: "user", content: prompt } ] }
      body[:system] = system if system

      response = connection.post(API_URL) do |req|
        req.headers["x-api-key"] = @api_key
        req.headers["anthropic-version"] = API_VERSION
        req.headers["content-type"] = "application/json"
        req.body = body.to_json
      end

      raise Error, "Claude #{response.status}: #{response.body}" unless response.success?

      parsed = JSON.parse(response.body)
      parsed.dig("content", 0, "text")
    end

    private

    def connection
      @connection ||= Faraday.new do |f|
        f.options.timeout = 600
        f.options.open_timeout = 30
        f.adapter Faraday.default_adapter
      end
    end

    class Error < StandardError; end
  end
end
