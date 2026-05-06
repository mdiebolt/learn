# Rapid Serial Visual Presentation Reader — Implementation Plan

A Rails application for synchronized rapid serial visual presentation reading with AI-generated audio. Users upload EPUBs, the system extracts chapters using AI, generates audio with text-to-speech, and presents text word-by-word synchronized with audio playback using optimal recognition point alignment.

---

## Phase 1: Rails Setup & Core Models

### 1.1 Create New Rails Application

```bash
rails new rsvp_reader --database=postgresql --css=tailwind --main
cd rsvp_reader
```

Use `--main` to track Rails main branch. No `--javascript` flag — Rails defaults to importmap, which is what we want. Do not install Node.js.

### 1.2 Verify Ruby & Rails

Use the latest stable Ruby (3.4+). The Gemfile should point at Rails main:

```ruby
gem "rails", github: "rails/rails", branch: "main"
```

### 1.3 Add Required Gems

```ruby
# Gemfile
gem "rubyzip"           # EPUB parsing
gem "faraday"           # HTTP client for text-to-speech API
gem "anthropic"         # Claude API for chapter extraction
```

Solid Queue ships with Rails main. No additional job backend gem needed.

### 1.4 Configure Credentials

```bash
rails credentials:edit
```

Add:
```yaml
eleven_labs:
  api_key: YOUR_API_KEY

anthropic:
  api_key: YOUR_API_KEY
```

### 1.5 Create Text-to-Speech Initializer

Create `config/initializers/text_to_speech.rb`:

```ruby
module TextToSpeech
  mattr_accessor :provider
  mattr_accessor :api_key
  mattr_accessor :voice_id

  # ElevenLabs is the current provider
  self.provider = :eleven_labs
  self.api_key = Rails.application.credentials.dig(:eleven_labs, :api_key)

  # Rachel - calm, clear, American female
  # Good for long-form instructional content
  self.voice_id = "21m00Tcm4TlvDq8ikWAM"
end
```

### 1.6 Generate Authentication

Use the Rails authentication generator to set up User, Session, and Current:

```bash
rails generate authentication
```

This gives you `User`, `Session`, `Current.user`, `require_authentication`, and the sign-in/sign-up views.

### 1.7 Generate Models

```bash
rails g model Upload user:references title:string author:string status:integer processed_at:datetime
rails g model Upload::Chapter upload:references title:string position:integer content:text words:jsonb
rails g model Upload::Chapter::AudioSegment chapter:references timestamps:jsonb status:integer duration_seconds:float
```

Modify migrations before running:

**uploads migration:**
```ruby
t.integer :status, default: 0, null: false
```

**upload_chapters migration:**
```ruby
t.jsonb :words, default: []
add_index :upload_chapters, [:upload_id, :position]
```

**upload_chapter_audio_segments migration:**
```ruby
# Replace the default chapter reference with:
t.references :chapter, null: false, foreign_key: { to_table: :upload_chapters }
t.integer :status, default: 0, null: false
```

Run migrations:
```bash
rails db:migrate
```

### 1.8 Set Up Active Storage

```bash
rails active_storage:install
rails db:migrate
```

---

## Phase 2: Model Implementation

### 2.1 Upload Model

Create `app/models/upload.rb`:

```ruby
class Upload < ApplicationRecord
  include EpubParsing
  include ChapterExtraction

  belongs_to :user
  has_many :chapters, class_name: "Upload::Chapter", dependent: :destroy
  has_one_attached :source_file

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  validates :source_file, presence: true

  def process!
    transaction do
      processing!
      extract_metadata_from_epub!
      extract_chapters_from_epub!
      update!(status: :ready, processed_at: Time.current)
    end
  rescue => e
    failed!
    Rails.logger.error("[Upload] Processing failed for #{id}: #{e.message}")
    raise e
  end
end
```

### 2.2 Upload::EpubParsing Concern

Create `app/models/concerns/upload/epub_parsing.rb`:

```ruby
module Upload::EpubParsing
  extend ActiveSupport::Concern

  private

  DC_NAMESPACE = "http://purl.org/dc/elements/1.1/"
  OPF_NAMESPACE = "http://www.idpf.org/2007/opf"
  CONTAINER_NAMESPACE = "urn:oasis:names:tc:opendocument:xmlns:container"
  NCX_NAMESPACE = "http://www.daisy.org/z3986/2005/ncx/"

  def extract_metadata_from_epub!
    with_epub do |zip|
      opf_doc = opf_document(zip)

      update!(
        title: opf_doc.at_xpath("//dc:title", dc: DC_NAMESPACE)&.text,
        author: opf_doc.at_xpath("//dc:creator", dc: DC_NAMESPACE)&.text
      )
    end
  end

  def with_epub(&block)
    tempfile = download_to_tempfile
    Zip::File.open(tempfile.path, &block)
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def download_to_tempfile
    tempfile = Tempfile.new(["upload", ".epub"])
    tempfile.binmode
    tempfile.write(source_file.download)
    tempfile.rewind
    tempfile
  end

  def opf_path(zip)
    container = Nokogiri::XML(zip.read("META-INF/container.xml"))
    container.at_xpath("//container:rootfile", container: CONTAINER_NAMESPACE)["full-path"]
  end

  def opf_document(zip)
    Nokogiri::XML(zip.read(opf_path(zip)))
  end

  def spine_items(zip)
    path = opf_path(zip)
    opf = opf_document(zip)
    manifest = build_manifest(opf)

    opf.xpath("//opf:spine/opf:itemref", opf: OPF_NAMESPACE).map do |itemref|
      idref = itemref["idref"]
      href = manifest[idref]
      content_path = resolve_path(path, href)

      {
        href: href,
        raw_html: zip.read(content_path)
      }
    end
  end

  def toc_titles(zip)
    path = opf_path(zip)
    opf = opf_document(zip)

    nav_item = opf.at_xpath("//opf:manifest/opf:item[@properties='nav']", opf: OPF_NAMESPACE)

    if nav_item
      extract_nav_toc(zip, resolve_path(path, nav_item["href"]))
    else
      ncx_item = opf.at_xpath("//opf:manifest/opf:item[@media-type='application/x-dtbncx+xml']", opf: OPF_NAMESPACE)
      ncx_item ? extract_ncx_toc(zip, resolve_path(path, ncx_item["href"])) : {}
    end
  end

  def build_manifest(opf_doc)
    opf_doc.xpath("//opf:manifest/opf:item", opf: OPF_NAMESPACE)
           .each_with_object({}) { |item, hash| hash[item["id"]] = item["href"] }
  end

  def resolve_path(opf_path, href)
    base_dir = File.dirname(opf_path)
    base_dir == "." ? href : File.join(base_dir, href)
  end

  def extract_nav_toc(zip, nav_path)
    doc = Nokogiri::HTML(zip.read(nav_path))
    doc.css("nav[epub|type='toc'] a, nav#toc a").each_with_object({}) do |link, hash|
      href = link["href"]&.split("#")&.first
      hash[href] = link.text.strip if href
    end
  end

  def extract_ncx_toc(zip, ncx_path)
    doc = Nokogiri::XML(zip.read(ncx_path))
    doc.xpath("//ncx:navPoint", ncx: NCX_NAMESPACE).each_with_object({}) do |point, hash|
      label = point.at_xpath("ncx:navLabel/ncx:text", ncx: NCX_NAMESPACE)&.text
      src = point.at_xpath("ncx:content", ncx: NCX_NAMESPACE)&.[]("src")&.split("#")&.first
      hash[src] = label if src && label
    end
  end
end
```

### 2.3 Upload::ChapterExtraction Concern

Create `app/models/concerns/upload/chapter_extraction.rb`:

```ruby
module Upload::ChapterExtraction
  extend ActiveSupport::Concern

  def extract_chapters_from_epub!
    with_epub do |zip|
      raw_chapters = parse_raw_chapters(zip)
      refined_chapters = refine_chapters_with_ai(raw_chapters)

      refined_chapters.each do |chapter_data|
        chapters.create!(
          position: chapter_data[:position],
          title: chapter_data[:title],
          content: chapter_data[:content]
        ).preprocess_words!
      end
    end
  end

  private

  def parse_raw_chapters(zip)
    toc = toc_titles(zip)

    spine_items(zip).map.with_index do |item, index|
      {
        position: index,
        title: toc[item[:href]] || "Chapter #{index + 1}",
        raw_html: item[:raw_html],
        content: html_to_text(item[:raw_html])
      }
    end
  end

  def html_to_text(html)
    doc = Nokogiri::HTML(html)
    doc.css("script, style, nav, header, footer").remove
    doc.css("body").text.gsub(/\n{3,}/, "\n\n").strip
  end

  def refine_chapters_with_ai(raw_chapters)
    summaries = raw_chapters.map do |ch|
      {
        index: ch[:position],
        title: ch[:title],
        word_count: ch[:content].split.size,
        first_500_chars: ch[:content][0, 500],
        last_200_chars: ch[:content][-200..] || ch[:content]
      }
    end

    analysis = request_chapter_analysis(summaries)

    analysis["chapters"]
      .select { |ch| ch["include"] && !ch["is_front_matter"] && !ch["is_back_matter"] }
      .map.with_index do |ch, new_position|
        original = raw_chapters[ch["original_index"]]
        {
          position: new_position,
          title: ch["suggested_title"] || original[:title],
          content: original[:content]
        }
      end
  end

  def request_chapter_analysis(summaries)
    response = anthropic_client.messages(
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      system: chapter_analysis_system_prompt,
      messages: [{ role: "user", content: chapter_analysis_prompt(summaries) }]
    )

    JSON.parse(response.content.first.text)
  end

  def chapter_analysis_system_prompt
    <<~PROMPT
      You are analyzing the structure of an EPUB book that has been parsed into segments.
      Your job is to identify which segments are actual content chapters vs front/back matter,
      and to suggest better chapter titles where the extracted title is generic or missing.

      Respond with JSON only. No markdown fences, no explanation.
    PROMPT
  end

  def chapter_analysis_prompt(summaries)
    <<~PROMPT
      Here are the segments extracted from an EPUB:

      #{summaries.to_json}

      Analyze this structure and return JSON with:
      {
        "chapters": [
          {
            "original_index": 0,
            "include": true,
            "suggested_title": "Chapter 1: Introduction to Financial Statements",
            "is_front_matter": false,
            "is_back_matter": false
          }
        ]
      }

      Mark front matter (title pages, copyright, TOC, dedications) and back matter
      (appendices, indexes, about the author) appropriately. Only set include: true for
      actual content chapters the reader should study.
    PROMPT
  end

  def anthropic_client
    @anthropic_client ||= Anthropic::Client.new
  end
end
```

### 2.4 Upload::Chapter Model

Create `app/models/upload/chapter.rb`:

```ruby
class Upload::Chapter < ApplicationRecord
  include WordProcessing

  self.table_name = "upload_chapters"

  belongs_to :upload
  has_one :audio_segment, class_name: "Upload::Chapter::AudioSegment", foreign_key: :chapter_id, dependent: :destroy

  validates :title, :position, :content, presence: true

  default_scope { order(:position) }

  def generate_audio!
    segment = audio_segment || create_audio_segment!(status: :pending)
    segment.generate!
  end

  def audio_ready?
    audio_segment&.ready?
  end

  def word_count
    content.split.size
  end

  def estimated_duration_minutes
    (word_count / 150.0).ceil
  end
end
```

### 2.5 Upload::Chapter::WordProcessing Concern

Create `app/models/concerns/upload/chapter/word_processing.rb`:

The "words" column stores preprocessed data with optimal recognition point positions.
The optimal recognition point is the character position where the brain most efficiently
recognizes a word. Longer words shift the focal character further left. This is the
technique popularized by Spritz for rapid serial visual presentation.

```ruby
module Upload::Chapter::WordProcessing
  extend ActiveSupport::Concern

  # Preprocesses chapter content into word data with optimal recognition points.
  #
  # Stores an array of hashes in the words jsonb column:
  #   [
  #     { index: 0, word: "Generally", optimal_recognition_point: 2, focal_character: "n" },
  #     { index: 1, word: "accepted", optimal_recognition_point: 2, focal_character: "c" },
  #   ]
  def preprocess_words!
    self.words = content.split(/\s+/).map.with_index do |word, index|
      recognition_point = optimal_recognition_point_for(word)
      {
        index: index,
        word: word,
        optimal_recognition_point: recognition_point,
        focal_character: word[recognition_point]
      }
    end
    save!
  end

  private

  def optimal_recognition_point_for(word)
    clean = word.gsub(/[^a-zA-Z]/, "")
    length = clean.length

    base_position = case length
                    when 0..1 then 0
                    when 2..5 then 1
                    when 6..9 then 2
                    when 10..13 then 3
                    else 4
                    end

    leading_punctuation_length = word.match(/^[^a-zA-Z]*/)[0].length
    [base_position + leading_punctuation_length, word.length - 1].min
  end
end
```

### 2.6 Upload::Chapter::AudioSegment Model

Create `app/models/upload/chapter/audio_segment.rb`:

```ruby
class Upload::Chapter::AudioSegment < ApplicationRecord
  include SpeechGeneration

  self.table_name = "upload_chapter_audio_segments"

  belongs_to :chapter, class_name: "Upload::Chapter"
  has_one_attached :audio_file

  enum :status, { pending: 0, processing: 1, ready: 2, failed: 3 }

  # timestamps column structure:
  # [
  #   { "word": "Generally", "start": 0.0, "end": 0.42, "optimal_recognition_point": 2 },
  #   { "word": "accepted", "start": 0.45, "end": 0.89, "optimal_recognition_point": 2 },
  # ]

  def word_at_time(seconds)
    timestamps.find do |t|
      seconds >= t["start"] && seconds < t["end"]
    end
  end

  def formatted_duration
    return "0:00" unless duration_seconds

    minutes = (duration_seconds / 60).floor
    seconds = (duration_seconds % 60).round

    "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
  end
end
```

### 2.7 Upload::Chapter::AudioSegment::SpeechGeneration Concern

Create `app/models/concerns/upload/chapter/audio_segment/speech_generation.rb`:

This concern provides domain-level speech generation methods. It delegates to
the ElevenLabs client internally but exposes only domain concepts (synthesize
speech, extract word timestamps, calculate optimal recognition points). If the
text-to-speech provider changes, only this concern and the client need updating.

```ruby
module Upload::Chapter::AudioSegment::SpeechGeneration
  extend ActiveSupport::Concern

  def generate!
    return if ready?

    processing!

    begin
      result = synthesize_speech(chapter.content)

      audio_file.attach(
        io: StringIO.new(result[:audio]),
        filename: "chapter_#{chapter.id}.mp3",
        content_type: "audio/mpeg"
      )

      update!(
        status: :ready,
        timestamps: result[:timestamps],
        duration_seconds: result[:timestamps].last&.dig(:end) || 0
      )
    rescue => e
      failed!
      Rails.logger.error("[SpeechGeneration] AudioSegment #{id} failed: #{e.message}")
      raise
    end
  end

  private

  # Domain-level speech synthesis

  def synthesize_speech(text)
    if text.length > 4500
      synthesize_speech_in_chunks(text)
    else
      synthesize_single_passage(text)
    end
  end

  def synthesize_single_passage(text)
    raw_response = speech_client.generate_speech_with_timestamps(text)

    {
      audio: decode_audio(raw_response),
      timestamps: extract_word_timestamps(raw_response)
    }
  end

  def synthesize_speech_in_chunks(text)
    chunks = split_at_sentence_boundaries(text)

    audio_parts = []
    all_timestamps = []
    time_offset = 0.0

    chunks.each do |chunk|
      raw_response = speech_client.generate_speech_with_timestamps(chunk)

      audio_parts << decode_audio(raw_response)

      chunk_timestamps = extract_word_timestamps(raw_response).map do |t|
        t.merge(start: t[:start] + time_offset, end: t[:end] + time_offset)
      end

      all_timestamps.concat(chunk_timestamps)
      time_offset = all_timestamps.last[:end] + 0.1
    end

    {
      audio: concatenate_audio_parts(audio_parts),
      timestamps: all_timestamps
    }
  end

  # Timestamp extraction — converts provider-specific character-level
  # timing data into domain word objects with optimal recognition points

  def extract_word_timestamps(raw_response)
    alignment = raw_response["alignment"]
    characters = alignment["characters"]
    starts = alignment["character_start_times_seconds"]
    ends = alignment["character_end_times_seconds"]

    words = []
    current = { chars: [], start: nil, end: nil }

    characters.each_with_index do |char, idx|
      if char.match?(/\s/)
        words << build_word_timestamp(current) if current[:chars].any?
        current = { chars: [], start: nil, end: nil }
      else
        current[:chars] << char
        current[:start] ||= starts[idx]
        current[:end] = ends[idx]
      end
    end

    words << build_word_timestamp(current) if current[:chars].any?
    words
  end

  def build_word_timestamp(accumulator)
    word = accumulator[:chars].join
    {
      word: word,
      start: accumulator[:start],
      end: accumulator[:end],
      optimal_recognition_point: optimal_recognition_point_for(word)
    }
  end

  def decode_audio(raw_response)
    Base64.decode64(raw_response["audio_base64"])
  end

  # Optimal recognition point calculation

  def optimal_recognition_point_for(word)
    clean = word.gsub(/[^a-zA-Z]/, "")
    length = clean.length

    base_position = case length
                    when 0..1 then 0
                    when 2..5 then 1
                    when 6..9 then 2
                    when 10..13 then 3
                    else 4
                    end

    leading_punctuation_length = word.match(/^[^a-zA-Z]*/)[0].length
    [base_position + leading_punctuation_length, word.length - 1].min
  end

  # Text chunking and audio concatenation

  def split_at_sentence_boundaries(text, max_chars: 4500)
    chunks = []
    current_chunk = ""

    text.split(/(?<=[.!?])\s+/).each do |sentence|
      if current_chunk.length + sentence.length > max_chars
        chunks << current_chunk.strip unless current_chunk.empty?
        current_chunk = sentence
      else
        current_chunk += " " + sentence
      end
    end

    chunks << current_chunk.strip unless current_chunk.empty?
    chunks
  end

  def concatenate_audio_parts(audio_parts)
    return audio_parts.first if audio_parts.size == 1

    inputs = audio_parts.map.with_index do |data, i|
      path = Rails.root.join("tmp", "audio_part_#{SecureRandom.hex(8)}_#{i}.mp3")
      File.binwrite(path, data)
      path
    end

    output_path = Rails.root.join("tmp", "audio_concat_#{SecureRandom.hex(8)}.mp3")
    concat_file = Rails.root.join("tmp", "concat_#{SecureRandom.hex(8)}.txt")

    File.write(concat_file, inputs.map { |p| "file '#{p}'" }.join("\n"))

    system("ffmpeg", "-f", "concat", "-safe", "0",
           "-i", concat_file.to_s,
           "-c", "copy", output_path.to_s,
           "-y", "-loglevel", "error")

    result = File.binread(output_path)

    [*inputs, concat_file, output_path].each { |p| File.delete(p) if File.exist?(p) }

    result
  end

  # Client

  def speech_client
    @speech_client ||= ElevenLabs::Client.new
  end
end
```

---

## Phase 3: ElevenLabs Client

The ElevenLabs client is a thin HTTP wrapper. It knows about the ElevenLabs API
but does not contain domain logic — that lives in the SpeechGeneration concern.

### 3.1 Create ElevenLabs Client

Create `app/clients/eleven_labs/client.rb`:

```ruby
module ElevenLabs
  class Client
    API_BASE = "https://api.elevenlabs.io/v1"

    def initialize(api_key: TextToSpeech.api_key, voice_id: TextToSpeech.voice_id)
      @api_key = api_key
      @voice_id = voice_id
    end

    # Returns the raw API response hash:
    # {
    #   "audio_base64" => "...",
    #   "alignment" => {
    #     "characters" => ["H", "e", "l", "l", "o", " ", ...],
    #     "character_start_times_seconds" => [0.0, 0.05, ...],
    #     "character_end_times_seconds" => [0.05, 0.08, ...]
    #   }
    # }
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
```

---

## Phase 4: Background Jobs

### 4.1 Upload Processing Job

Create `app/jobs/upload/process_job.rb`:

```ruby
class Upload::ProcessJob < ApplicationJob
  queue_as :default

  def perform(upload_id)
    Upload.find(upload_id).process!
  end
end
```

### 4.2 Audio Generation Job

Create `app/jobs/upload/chapter/generate_audio_job.rb`:

```ruby
class Upload::Chapter::GenerateAudioJob < ApplicationJob
  queue_as :audio_generation

  retry_on ElevenLabs::Client::RateLimitError, wait: :polynomially_longer, attempts: 5

  def perform(chapter_id)
    chapter = Upload::Chapter.find(chapter_id)
    segment = chapter.audio_segment || chapter.create_audio_segment!(status: :pending)
    segment.generate!
  end
end
```

---

## Phase 5: Controllers

### 5.1 Uploads Controller

Create `app/controllers/uploads_controller.rb`:

Note: The Rails authentication generator provides `require_authentication` and `Current.user`.

```ruby
class UploadsController < ApplicationController
  before_action :require_authentication
  before_action :set_upload, only: [:show, :destroy]

  def index
    @uploads = Current.user.uploads.order(created_at: :desc)
  end

  def show
  end

  def new
    @upload = Upload.new
  end

  def create
    @upload = Current.user.uploads.new(upload_params)

    if @upload.save
      Upload::ProcessJob.perform_later(@upload.id)
      redirect_to @upload, notice: "Upload is being processed..."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @upload.destroy
    redirect_to uploads_path, notice: "Upload deleted."
  end

  private

  def set_upload
    @upload = Current.user.uploads.find(params[:id])
  end

  def upload_params
    params.require(:upload).permit(:source_file)
  end
end
```

### 5.2 Chapters Controller

Create `app/controllers/uploads/chapters_controller.rb`:

```ruby
module Uploads
  class ChaptersController < ApplicationController
    before_action :require_authentication
    before_action :set_upload
    before_action :set_chapter

    def show
      ensure_audio_generation
    end

    def audio_status
      segment = @chapter.audio_segment

      respond_to do |format|
        format.json do
          render json: {
            status: segment&.status || "pending",
            audio_url: segment&.ready? ? url_for(segment.audio_file) : nil,
            timestamps: segment&.ready? ? segment.timestamps : nil,
            duration: segment&.formatted_duration
          }
        end

        format.turbo_stream do
          if segment&.ready?
            render turbo_stream: turbo_stream.replace(
              "audio-player",
              partial: "uploads/chapters/audio_player",
              locals: { chapter: @chapter, segment: segment }
            )
          else
            head :no_content
          end
        end
      end
    end

    private

    def set_upload
      @upload = Current.user.uploads.find(params[:upload_id])
    end

    def set_chapter
      @chapter = @upload.chapters.find(params[:id])
    end

    def ensure_audio_generation
      segment = @chapter.audio_segment

      if segment.nil?
        @chapter.create_audio_segment!(status: :pending)
        Upload::Chapter::GenerateAudioJob.perform_later(@chapter.id)
      elsif segment.failed?
        segment.pending!
        Upload::Chapter::GenerateAudioJob.perform_later(@chapter.id)
      end
    end
  end
end
```

---

## Phase 6: Routes

Update `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  resources :uploads, only: [:index, :show, :new, :create, :destroy] do
    resources :chapters, only: [:show], controller: "uploads/chapters" do
      member do
        get :audio_status
      end
    end
  end

  root "uploads#index"
end
```

---

## Phase 7: Views

### 7.1 Uploads Index

Create `app/views/uploads/index.html.erb`:

```erb
<div class="max-w-4xl mx-auto py-8 px-4">
  <div class="flex justify-between items-center mb-8">
    <h1 class="text-3xl font-bold">Your Books</h1>
    <%= link_to "Upload  Book", new_upload_path, class: "bg-gray-950 text-white px-4 py-2 hover:bg-gray-950/83" %>
  </div>

  <% if @uploads.any? %>
    <div class="space-y-4">
      <% @uploads.each do |upload| %>
        <%= render "upload", upload: upload %>
      <% end %>
    </div>
  <% else %>
    <div class="text-center py-12 text-gray-500">
      <p class="mb-4">No books uploaded yet.</p>
      <%= link_to "Upload your first book", new_upload_path, class: "text-blue-600 hover:underline" %>
    </div>
  <% end %>
</div>
```

### 7.2 Upload Partial

Create `app/views/uploads/_upload.html.erb`:

```erb
<div class="bg-white rounded-lg shadow p-6">
  <div class="flex justify-between items-start">
    <div>
      <h2 class="text-xl font-semibold">
        <%= link_to upload.title || "Processing...", upload, class: "hover:text-blue-600" %>
      </h2>
      <p class="text-gray-600"><%= upload.author %></p>
      <p class="text-sm text-gray-400 mt-2">
        <% if upload.ready? %>
          <%= pluralize(upload.chapters.count, "chapter") %>
        <% else %>
          Status: <%= upload.status.humanize %>
        <% end %>
      </p>
    </div>

    <% if upload.ready? %>
      <span class="bg-green-100 text-green-800 text-xs px-2 py-1 rounded">Ready</span>
    <% elsif upload.processing? %>
      <span class="bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded">Processing</span>
    <% elsif upload.failed? %>
      <span class="bg-red-100 text-red-800 text-xs px-2 py-1 rounded">Failed</span>
    <% end %>
  </div>
</div>
```

### 7.3 Upload Show

Create `app/views/uploads/show.html.erb`:

```erb
<div class="max-w-4xl mx-auto py-8 px-4">
  <%= link_to "← Back to Books", uploads_path, class: "text-gray-600 hover:text-gray-900 mb-4 inline-block" %>

  <header class="mb-8">
    <h1 class="text-3xl font-bold"><%= @upload.title %></h1>
    <p class="text-xl text-gray-600"><%= @upload.author %></p>
  </header>

  <% if @upload.ready? %>
    <div class="space-y-2">
      <% @upload.chapters.each do |chapter| %>
        <div class="bg-white rounded-lg shadow p-4 flex justify-between items-center">
          <div>
            <h3 class="font-medium">
              <%= link_to chapter.title, upload_chapter_path(@upload, chapter), class: "hover:text-blue-600" %>
            </h3>
            <p class="text-sm text-gray-500">
              ~<%= chapter.estimated_duration_minutes %> min
            </p>
          </div>

          <% if chapter.audio_ready? %>
            <span class="text-green-600 text-sm">Audio ready</span>
          <% end %>
        </div>
      <% end %>
    </div>
  <% elsif @upload.processing? %>
    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-8 text-center">
      <p class="text-yellow-800">Processing your book... This may take a minute.</p>
    </div>
  <% else %>
    <div class="bg-red-50 border border-red-200 rounded-lg p-8 text-center">
      <p class="text-red-800">Processing failed. Please try uploading again.</p>
    </div>
  <% end %>
</div>
```

### 7.4 Upload New

Create `app/views/uploads/new.html.erb`:

```erb
<div class="max-w-xl mx-auto py-8 px-4">
  <h1 class="text-3xl font-bold mb-8">Upload a Book</h1>

  <%= form_with model: @upload, class: "space-y-6" do |f| %>
    <% if @upload.errors.any? %>
      <div class="bg-red-50 border border-red-200 rounded-lg p-4">
        <ul class="text-red-800 text-sm">
          <% @upload.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    <% end %>

    <div>
      <%= f.label :source_file, "EPUB File", class: "block text-sm font-medium text-gray-700 mb-2" %>
      <%= f.file_field :source_file, accept: ".epub", class: "block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100" %>
    </div>

    <div>
      <%= f.submit "Upload", class: "w-full bg-blue-600 text-white py-3 px-4 rounded-lg hover:bg-blue-700 cursor-pointer" %>
    </div>
  <% end %>
</div>
```

### 7.5 Chapter Show (Reader)

Create `app/views/uploads/chapters/show.html.erb`:

```erb
<div class="min-h-screen bg-gray-900 text-white">
  <header class="p-4 border-b border-gray-700">
    <%= link_to "← #{@upload.title}", @upload, class: "text-gray-400 hover:text-white" %>
    <h1 class="text-xl font-semibold mt-2"><%= @chapter.title %></h1>
  </header>

  <div id="audio-player" class="flex-1">
    <% if @chapter.audio_segment&.ready? %>
      <%= render "audio_player", chapter: @chapter, segment: @chapter.audio_segment %>
    <% else %>
      <%= render "audio_loading", chapter: @chapter %>
    <% end %>
  </div>
</div>
```

### 7.6 Audio Loading Partial

Create `app/views/uploads/chapters/_audio_loading.html.erb`:

```erb
<div class="flex flex-col items-center justify-center h-96"
     data-controller="poll"
     data-poll-url-value="<%= audio_status_upload_chapter_path(@upload, chapter) %>"
     data-poll-interval-value="2000">

  <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-white mb-4"></div>
  <p class="text-gray-400">Generating audio... This may take a minute.</p>
</div>
```

### 7.7 Audio Player Partial (Reader Interface)

Create `app/views/uploads/chapters/_audio_player.html.erb`:

```erb
<div class="serial-reader p-8"
     data-controller="serial-presentation audio-sync"
     data-audio-sync-timestamps-value="<%= segment.timestamps.to_json %>">

  <%# Serial Presentation Display %>
  <div class="presentation-display bg-gray-800 rounded-lg h-48 flex items-center justify-center mb-8 relative">
    <div class="word-container font-mono text-4xl flex">
      <span class="word-before-focal text-gray-400 text-right" style="min-width: 200px;" data-serial-presentation-target="beforeFocal"></span>
      <span class="word-focal-character text-red-500 font-bold" data-serial-presentation-target="focalCharacter"></span>
      <span class="word-after-focal text-gray-400 text-left" style="min-width: 200px;" data-serial-presentation-target="afterFocal"></span>
    </div>
    <div class="absolute left-1/2 top-0 bottom-0 w-0.5 bg-red-500/30 transform -translate-x-1/2"></div>
  </div>

  <%# Audio Element %>
  <audio data-audio-sync-target="audio"
         data-action="timeupdate->audio-sync#onTimeUpdate play->audio-sync#onPlay pause->audio-sync#onPause"
         preload="auto"
         class="hidden">
    <source src="<%= url_for(segment.audio_file) %>" type="audio/mpeg">
  </audio>

  <%# Controls %>
  <div class="flex items-center gap-6 justify-center">
    <button data-action="click->audio-sync#toggle"
            data-audio-sync-target="playButton"
            class="bg-white text-gray-900 w-16 h-16 rounded-full flex items-center justify-center hover:bg-gray-200 transition">
      <span data-audio-sync-target="playIcon" class="text-2xl">▶</span>
    </button>

    <div class="flex-1 max-w-md">
      <div class="flex items-center gap-3 text-sm text-gray-400 mb-2">
        <span data-audio-sync-target="currentTime">0:00</span>
        <div class="flex-1 h-2 bg-gray-700 rounded-full cursor-pointer" data-action="click->audio-sync#seek">
          <div class="h-full bg-white rounded-full transition-all" data-audio-sync-target="progress" style="width: 0%"></div>
        </div>
        <span><%= segment.formatted_duration %></span>
      </div>
    </div>

    <div class="flex items-center gap-2">
      <label class="text-sm text-gray-400">Speed</label>
      <select data-action="change->audio-sync#setSpeed"
              data-audio-sync-target="speedSelect"
              class="bg-gray-800 border border-gray-600 rounded px-2 py-1 text-sm">
        <option value="0.75">0.75x</option>
        <option value="1" selected>1x</option>
        <option value="1.25">1.25x</option>
        <option value="1.5">1.5x</option>
        <option value="2">2x</option>
      </select>
    </div>
  </div>

  <%# Full Text Toggle %>
  <details class="mt-12">
    <summary class="text-gray-500 cursor-pointer hover:text-gray-300">Show full text</summary>
    <div class="mt-4 text-gray-300 leading-relaxed max-h-96 overflow-y-auto">
      <%= simple_format(chapter.content) %>
    </div>
  </details>
</div>
```

---

## Phase 8: Stimulus Controllers

These are managed via importmap. Stimulus is pinned by default in Rails main. Controllers in `app/javascript/controllers/` are auto-registered.

### 8.1 Poll Controller

Create `app/javascript/controllers/poll_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 2000 }
  }

  connect() {
    this.poll()
  }

  disconnect() {
    this.stopPolling()
  }

  poll() {
    this.timer = setInterval(() => {
      fetch(this.urlValue, {
        headers: { "Accept": "text/vnd.turbo-stream.html" }
      })
      .then(response => {
        if (response.ok && response.headers.get("Content-Type")?.includes("turbo-stream")) {
          return response.text()
        }
        return null
      })
      .then(html => {
        if (html) {
          Turbo.renderStreamMessage(html)
          this.stopPolling()
        }
      })
    }, this.intervalValue)
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }
}
```

### 8.2 Audio Sync Controller

Create `app/javascript/controllers/audio_sync_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "playButton", "playIcon", "progress", "currentTime", "speedSelect"]
  static values = { timestamps: Array }

  connect() {
    this.currentWordIndex = -1
  }

  toggle() {
    if (this.audioTarget.paused) {
      this.audioTarget.play()
    } else {
      this.audioTarget.pause()
    }
  }

  onPlay() {
    this.playIconTarget.textContent = "⏸"
  }

  onPause() {
    this.playIconTarget.textContent = "▶"
  }

  onTimeUpdate() {
    const time = this.audioTarget.currentTime
    const duration = this.audioTarget.duration

    if (duration) {
      const percent = (time / duration) * 100
      this.progressTarget.style.width = `${percent}%`
    }

    this.currentTimeTarget.textContent = this.formatTime(time)
    this.updateCurrentWord(time)
  }

  updateCurrentWord(time) {
    const index = this.timestampsValue.findIndex((t, i) => {
      const next = this.timestampsValue[i + 1]
      return time >= t.start && (!next || time < next.start)
    })

    if (index !== -1 && index !== this.currentWordIndex) {
      this.currentWordIndex = index
      this.dispatch("wordChange", { detail: this.timestampsValue[index] })
    }
  }

  seek(event) {
    const rect = event.currentTarget.getBoundingClientRect()
    const percent = (event.clientX - rect.left) / rect.width
    this.audioTarget.currentTime = this.audioTarget.duration * percent
  }

  setSpeed(event) {
    this.audioTarget.playbackRate = parseFloat(event.target.value)
  }

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }
}
```

### 8.3 Serial Presentation Controller

Create `app/javascript/controllers/serial_presentation_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Handles rapid serial visual presentation of words.
// Listens for wordChange events dispatched by the audio-sync controller
// and renders each word split around its optimal recognition point
// (focal character) to maintain a consistent fixation position.

export default class extends Controller {
  static targets = ["beforeFocal", "focalCharacter", "afterFocal"]

  connect() {
    this.onWordChange = this.onWordChange.bind(this)
    this.element.addEventListener("audio-sync:wordChange", this.onWordChange)
  }

  disconnect() {
    this.element.removeEventListener("audio-sync:wordChange", this.onWordChange)
  }

  onWordChange(event) {
    const { word, optimal_recognition_point } = event.detail
    this.renderWord(word, optimal_recognition_point)
  }

  renderWord(word, optimalRecognitionPoint) {
    if (!word) return

    const safeIndex = Math.min(optimalRecognitionPoint || 0, word.length - 1)

    this.beforeFocalTarget.textContent = word.slice(0, safeIndex)
    this.focalCharacterTarget.textContent = word[safeIndex] || ""
    this.afterFocalTarget.textContent = word.slice(safeIndex + 1)
  }
}
```

---

## Phase 9: Testing

### 9.1 Key Test Cases

1. **EPUB Parsing**: Upload a sample EPUB, verify chapters extracted correctly
2. **Chapter Extraction**: Verify AI filters front/back matter appropriately
3. **Word Processing**: Test optimal recognition point calculation for various word lengths, punctuation, edge cases
4. **Speech Generation**: Mock ElevenLabs API, verify timestamp processing
5. **Serial Presentation Display**: System test that audio plays and words display

### 9.2 Sample Tests

```ruby
# test/models/upload_test.rb
require "test_helper"

class UploadTest < ActiveSupport::TestCase
  test "processes epub and extracts chapters" do
    upload = uploads(:sample)
    upload.source_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/sample.epub")),
      filename: "sample.epub"
    )

    upload.process!

    assert upload.ready?
    assert upload.title.present?
    assert upload.chapters.any?
  end
end
```

```ruby
# test/models/concerns/upload/chapter/word_processing_test.rb
require "test_helper"

class Upload::Chapter::WordProcessingTest < ActiveSupport::TestCase
  test "calculates optimal recognition point for short words" do
    chapter = Upload::Chapter.new(content: "I am ok", title: "Test", position: 0)
    chapter.preprocess_words!

    assert_equal 0, chapter.words[0]["optimal_recognition_point"]  # "I" — 1 char
    assert_equal 1, chapter.words[1]["optimal_recognition_point"]  # "am" — 2 chars
    assert_equal 1, chapter.words[2]["optimal_recognition_point"]  # "ok" — 2 chars
  end

  test "calculates optimal recognition point for longer words" do
    chapter = Upload::Chapter.new(content: "Generally accepted accounting", title: "Test", position: 0)
    chapter.preprocess_words!

    assert_equal 2, chapter.words[0]["optimal_recognition_point"]  # "Generally" — 9 chars
    assert_equal 2, chapter.words[1]["optimal_recognition_point"]  # "accepted" — 8 chars
    assert_equal 2, chapter.words[2]["optimal_recognition_point"]  # "accounting" — 10 chars
  end

  test "adjusts optimal recognition point for leading punctuation" do
    chapter = Upload::Chapter.new(content: '"Hello world"', title: "Test", position: 0)
    chapter.preprocess_words!

    # Leading quote shifts the recognition point right by 1
    assert_equal 2, chapter.words[0]["optimal_recognition_point"]  # '"Hello' — quote + 5 chars
  end
end
```

---

## Implementation Order

1. **Phase 1**: Rails setup with authentication, models, Active Storage
2. **Phase 2**: Model concerns (EPUB parsing, chapter extraction, word processing, speech generation)
3. **Phase 3**: ElevenLabs client
4. **Phase 4**: Background jobs
5. **Phase 5-6**: Controllers and routes
6. **Phase 7-8**: Views and Stimulus controllers
7. **Phase 9**: Testing and refinement

Start Phase 1 with `rails generate authentication` early so the User model and session infrastructure exist before creating Uploads.

---

## Environment Requirements

- Latest stable Ruby (3.4+)
- Rails main branch
- PostgreSQL
- Redis (for Solid Queue)
- ffmpeg (for audio concatenation of long chapters)
- **No Node.js** — uses importmap for JavaScript

---

## External Services

- **Anthropic Claude API**: Chapter extraction and structure analysis
- **ElevenLabs API**: Text-to-speech with character-level timestamps (Rachel voice: `21m00Tcm4TlvDq8ikWAM`)

---

## Directory Structure

```
app/
├── clients/
│   └── eleven_labs/
│       └── client.rb               # Thin HTTP wrapper for ElevenLabs API
│
├── models/
│   ├── upload.rb
│   ├── upload/
│   │   ├── chapter.rb
│   │   └── chapter/
│   │       └── audio_segment.rb
│   └── concerns/
│       ├── upload/
│       │   ├── epub_parsing.rb              # EPUB zip handling, metadata extraction
│       │   └── chapter_extraction.rb        # AI-assisted chapter identification
│       └── upload/chapter/
│           ├── word_processing.rb           # Optimal recognition point calculation
│           └── audio_segment/
│               └── speech_generation.rb     # Domain-level TTS, timestamp processing
│
├── jobs/
│   ├── upload/
│   │   └── process_job.rb                   # Thin wrapper: Upload.find(id).process!
│   └── upload/chapter/
│       └── generate_audio_job.rb            # Thin wrapper: segment.generate!
│
├── controllers/
│   ├── uploads_controller.rb
│   └── uploads/
│       └── chapters_controller.rb
│
├── views/
│   ├── uploads/
│   │   ├── index.html.erb
│   │   ├── show.html.erb
│   │   ├── new.html.erb
│   │   └── _upload.html.erb
│   └── uploads/chapters/
│       ├── show.html.erb
│       ├── _audio_player.html.erb
│       └── _audio_loading.html.erb
│
└── javascript/
    └── controllers/                         # Auto-registered via importmap + Stimulus
        ├── poll_controller.js
        ├── audio_sync_controller.js
        └── serial_presentation_controller.js
```

---

## Architectural Notes for Claude Code

- **No services directory.** Use model concerns to enrich domain models.
- **No abbreviations in code.** Use `optimal_recognition_point` not `orp`. Use `serial_presentation` not `rsvp`. Use `focal_character` not `orp_char`.
- **Importmap for JavaScript.** No esbuild, no Node.js. Stimulus controllers live in `app/javascript/controllers/` and are auto-registered.
- **Rails authentication generator.** Use `require_authentication` (not `authenticate_user!`). Use `Current.user` for the current user.
- **Nested model namespacing.** `Upload::Chapter`, not `UploadChapter`. `Upload::Chapter::AudioSegment`, not `AudioSegment`.
- **Jobs are thin.** They find the record and call a model method. All logic lives in concerns.
- **Domain language over provider language.** The `SpeechGeneration` concern uses domain methods (`synthesize_speech`, `extract_word_timestamps`, `optimal_recognition_point_for`). The `ElevenLabs::Client` is a thin HTTP wrapper in `app/clients/`. If the provider changes, swap the client and update the concern's private methods.
- **Initializer uses domain module.** Configuration lives in `TextToSpeech` module, not `ElevenLabs`. The client reads from `TextToSpeech.api_key` and `TextToSpeech.voice_id`.
- **Rachel voice ID**: `21m00Tcm4TlvDq8ikWAM` — configured once in `config/initializers/text_to_speech.rb`.
