module ChaptersHelper
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
end
