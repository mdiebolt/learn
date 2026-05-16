# DOM construction for the RSVP (rapid serial visual presentation) chapter
# player: the controller wiring on the container/audio elements and the
# transport chrome (scrubber, sync offset, fullscreen, speed).
module RapidSerialVisualPresentationHelper
  def rsvp_container_attributes(audiobook:, chapter:, words:, next_chapter:, autoplay:, progress:)
    next_url = next_chapter ? audiobook_chapter_path(audiobook, next_chapter) : ""
    initial_progress_ms = (progress && !progress.completed?) ? progress.progress_ms : 0
    duration_ms = chapter.end_time_ms - chapter.start_time_ms
    natural_wpm = duration_ms.positive? ? (words.size * 60_000.0 / duration_ms) : 0

    {
      class: "min-h-dvh grid place-items-center relative overflow-hidden select-none cursor-default",
      data: {
        controller: "playback rsvp chapter-progress chapter-autoplay fullscreen",
        action: [
          "click->playback#togglePlayFromClick",
          "keydown.space@window->playback#togglePlayFromKey",
          "keydown.f@window->fullscreen#toggleFromKey",
          "playback:play->rsvp#onPlay",
          "playback:play->chapter-progress#onPlay",
          "playback:pause->rsvp#onPause",
          "playback:pause->chapter-progress#onPause",
          "playback:seeked->rsvp#onSeeked",
          "playback:seeked->chapter-progress#onSeeked",
          "playback:loadedmetadata->rsvp#onLoadedMetadata",
          "playback:loadedmetadata->chapter-autoplay#onLoadedMetadata",
          "playback:chapterend->rsvp#onChapterEnd",
          "playback:chapterend->chapter-progress#onChapterEnd",
          "playback:chapterend->chapter-autoplay#advance"
        ].join(" "),
        playback_start_ms_value: chapter.start_time_ms,
        playback_end_ms_value: chapter.end_time_ms,
        playback_initial_ms_value: initial_progress_ms,
        playback_natural_wpm_value: natural_wpm,
        rsvp_words_value: words.to_json,
        rsvp_audio_offset_ms_value: Current.user.audio_offset_ms,
        chapter_progress_url_value: audiobook_chapter_progress_path(audiobook, chapter),
        chapter_autoplay_autoplay_value: autoplay,
        chapter_autoplay_next_chapter_url_value: next_url,
        chapter_autoplay_playback_outlet: "[data-controller~='playback']"
      }
    }
  end

  def rsvp_audio_attributes
    {
      preload: "metadata",
      class: "hidden",
      data: {
        playback_target: "audio",
        rsvp_target: "audio",
        chapter_progress_target: "audio",
        action: [
          "play->playback#onPlay",
          "pause->playback#onPause",
          "seeked->playback#onSeeked",
          "loadedmetadata->playback#onLoadedMetadata",
          "timeupdate->playback#onTimeUpdate"
        ].join(" ")
      }
    }
  end

  # The bottom-edge seek bar.
  def rsvp_scrubber
    tag.input type: "range", autocomplete: "off",
      min: 0, max: 1000, value: 0, step: 1, name: "seek",
      aria: { label: "Seek" },
      data: { playback_target: "seek", action: "input->playback#seek" },
      class: "rsvp-scrubber"
  end

  # The audio-sync offset slider with its label and live `+Nms` readout.
  # Autosaves to the user's preferences on change.
  def rsvp_audio_offset_control
    offset = Current.user.audio_offset_ms

    tag.label class: "flex items-center gap-2 cursor-pointer", data: { playback_no_toggle: true } do
      safe_join([
        tag.span("sync", class: "text-white/40"),
        tag.input(type: "range", autocomplete: "off",
          min: User::AUDIO_OFFSET_MS_RANGE.begin,
          max: User::AUDIO_OFFSET_MS_RANGE.end,
          step: 25, value: offset, name: "audio_offset_ms",
          aria: { label: "Audio sync offset in milliseconds" },
          data: {
            rsvp_target: "audioOffset",
            controller: "autosave",
            autosave_url_value: preferences_path,
            action: "input->rsvp#setAudioOffset change->autosave#patch"
          },
          class: "w-20 accent-amber-400 cursor-pointer"),
        tag.span(format("%+dms", offset),
          data: { rsvp_target: "audioOffsetReadout" },
          class: "text-white/40 w-12 text-right")
      ])
    end
  end

  # Plain-text fullscreen toggle handled by the fullscreen controller.
  def rsvp_fullscreen_button
    tag.button "[fullscreen]", type: "button",
      aria: { label: "Toggle fullscreen" },
      data: { action: "fullscreen#toggle" },
      class: "bg-transparent border-0 text-white/60 hover:text-amber-400 cursor-pointer"
  end

  # Reading-speed select, preselected to the user's saved WPM and
  # autosaving the choice back to preferences.
  def rsvp_wpm_select
    selected = Current.user.wpm
    options = safe_join(User::WPM_OPTIONS.map { |wpm|
      tag.option("#{wpm} wpm", value: wpm, selected: wpm == selected, class: "bg-black text-white")
    })

    select_tag "wpm", options,
      aria: { label: "Reading speed" },
      data: {
        playback_target: "wpm",
        controller: "autosave",
        autosave_url_value: preferences_path,
        action: "change->playback#setRate change->autosave#patch"
      },
      class: "bg-transparent border-0 text-white/60 hover:text-amber-400 cursor-pointer uppercase tracking-wide font-mono"
  end
end
