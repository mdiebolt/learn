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

  def speech_client
    @speech_client ||= ElevenLabs::Client.new
  end
end
