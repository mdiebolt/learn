module AudiobooksHelper
  TRANSCRIBE_CONFIRM = "Run ElevenLabs Scribe? This incurs cost (~$0.40/hour of audio).".freeze

  def transcript_badge(audiobook, small: false)
    box = small ? "gap-1.5 px-2 py-0.5" : "gap-2 px-3 py-1.5"
    dot_size = small ? "size-1" : "size-1.5"
    id = dom_id(audiobook, :transcript_badge)

    case audiobook.transcription_status
    when :pending
      transcribe_button(audiobook, id:, box:, dot_size:,
        text: "transcribe", confirm: TRANSCRIBE_CONFIRM,
        chrome: "text-white/70 hover:text-amber-400 border border-white/20 hover:border-amber-400",
        dot_color: "bg-white/40")
    when :transcribing
      transcript_status_badge(id:, box:, dot_size:,
        text: audiobook.transcription_progress_message.presence || "transcribing…",
        chrome: "text-amber-400 border border-amber-400/40",
        dot_color: "bg-amber-400 animate-pulse")
    when :ready
      transcript_status_badge(id:, box:, dot_size:,
        text: "ready",
        chrome: "text-amber-400 border border-amber-400/40",
        dot_color: "bg-amber-400")
    when :failed
      transcribe_button(audiobook, id:, box:, dot_size:,
        text: "retry",
        chrome: "text-red-400 hover:text-white border border-red-400/40 hover:border-red-400",
        dot_color: "bg-red-400")
    end
  end

  def audiobook_status_chip(audiobook)
    color = audiobook.status.to_sym == :failed ? "text-red-400" : "text-white/50"
    tag.span "// #{audiobook.status}",
      class: "font-mono text-2xs uppercase tracking-wide shrink-0 #{color}"
  end

  def delete_audiobook_button(audiobook)
    button_to "[delete audiobook]", audiobook, method: :delete,
      form: { data: { turbo_confirm: "Delete this audiobook?" } },
      class: "ui-button text-white/40 hover:text-red-400"
  end

  private

  def transcribe_button(audiobook, id:, box:, dot_size:, text:, chrome:, dot_color:, confirm: nil)
    form = { id: id }
    form[:data] = { turbo_confirm: confirm } if confirm

    button_to audiobook_transcription_path(audiobook),
      method: :post,
      form: form,
      class: "ui-button inline-flex items-center #{box} #{chrome}" do
      concat tag.span(class: "#{dot_size} rounded-full #{dot_color}")
      concat " #{text}"
    end
  end

  def transcript_status_badge(id:, box:, dot_size:, text:, chrome:, dot_color:)
    tag.div id: id,
      class: "inline-flex items-center #{box} font-mono text-2xs uppercase tracking-wide #{chrome}" do
      concat tag.span(class: "#{dot_size} rounded-full #{dot_color}")
      concat " #{text}"
    end
  end
end
