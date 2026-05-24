# DOM construction for the RSVP (rapid serial visual presentation) chapter
# player: the controller wiring on the container/audio elements and the
# transport chrome (scrubber, fullscreen, speed).
module RapidSerialVisualPresentationHelper
  def rsvp_container_attributes(chapter:, words:, autoplay:, progress:)
    next_chapter = chapter.following
    next_url = next_chapter ? chapter_path(next_chapter) : ""
    initial_progress_ms = (progress && !progress.completed?) ? progress.progress_ms : 0
    duration_ms = chapter.end_time_ms - chapter.start_time_ms
    natural_wpm = duration_ms.positive? ? (words.size * 60_000.0 / duration_ms) : 0

    {
      class: "min-h-dvh grid place-items-center relative overflow-hidden select-none cursor-default",
      data: {
        controller: "playback--playback playback--rsvp playback--chapter-progress playback--chapter-autoplay fullscreen idle",
        action: [
          "click->playback--playback#togglePlayFromClick",
          "mousemove@window->idle#bump",
          "keydown.space@window->playback--playback#togglePlayFromKey",
          "keydown.f@window->fullscreen#toggleFromKey",
          "playback:play->playback--rsvp#onPlay",
          "playback:play->playback--chapter-progress#onPlay",
          "playback:pause->playback--rsvp#onPause",
          "playback:pause->playback--chapter-progress#onPause",
          "playback:seeked->playback--rsvp#onSeeked",
          "playback:seeked->playback--chapter-progress#onSeeked",
          "playback:loadedmetadata->playback--rsvp#onLoadedMetadata",
          "playback:loadedmetadata->playback--chapter-autoplay#onLoadedMetadata",
          "playback:chapterend->playback--rsvp#onChapterEnd",
          "playback:chapterend->playback--chapter-progress#onChapterEnd",
          "playback:chapterend->playback--chapter-autoplay#advance"
        ].join(" "),
        "playback--playback_start_ms_value": chapter.start_time_ms,
        "playback--playback_end_ms_value": chapter.end_time_ms,
        "playback--playback_initial_ms_value": initial_progress_ms,
        "playback--playback_natural_wpm_value": natural_wpm,
        "playback--rsvp_words_value": words.to_json,
        "playback--chapter-progress_url_value": chapter_progress_path(chapter),
        "playback--chapter-autoplay_autoplay_value": autoplay,
        "playback--chapter-autoplay_next_chapter_url_value": next_url,
        "playback--chapter-autoplay_playback--playback_outlet": "[data-controller~='playback--playback']"
      }
    }
  end

  def rsvp_audio_attributes
    {
      preload: "metadata",
      class: "hidden",
      data: {
        "playback--playback_target": "audio",
        "playback--rsvp_target": "audio",
        "playback--chapter-progress_target": "audio",
        action: [
          "play->playback--playback#onPlay",
          "pause->playback--playback#onPause",
          "seeked->playback--playback#onSeeked",
          "loadedmetadata->playback--playback#onLoadedMetadata",
          "timeupdate->playback--playback#onTimeUpdate"
        ].join(" ")
      }
    }
  end

  # The bottom-edge seek bar.
  def rsvp_scrubber
    tag.input type: "range", autocomplete: "off",
      min: 0, max: 1_000, value: 0, step: 1, name: "seek",
      aria: { label: "Seek" },
      data: { "playback--playback_target": "seek", action: "input->playback--playback#seek" },
      class: "rsvp-scrubber"
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
        "playback--playback_target": "wpm",
        controller: "autosave",
        autosave_url_value: preferences_path,
        action: "change->playback--playback#setRate change->autosave#patch"
      },
      class: "bg-transparent border-0 text-white/60 hover:text-amber-400 cursor-pointer uppercase tracking-wide font-mono"
  end
end
