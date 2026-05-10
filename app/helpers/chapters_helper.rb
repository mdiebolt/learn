module ChaptersHelper
  def rsvp_container_attributes(audiobook:, chapter:, words:, next_chapter:, autoplay:, progress:)
    next_url = next_chapter ? audiobook_chapter_path(audiobook, next_chapter) : ""
    initial_progress_ms = (progress && !progress.completed?) ? progress.progress_ms : 0

    {
      class: "min-h-dvh grid place-items-center relative overflow-hidden select-none cursor-default",
      data: {
        controller: "rsvp fullscreen",
        action: "click->rsvp#togglePlay keydown@window->rsvp#onKeydown keydown@window->fullscreen#onKeydown",
        rsvp_words_value: words.to_json,
        rsvp_start_ms_value: chapter.start_time_ms,
        rsvp_end_ms_value: chapter.end_time_ms,
        rsvp_next_chapter_url_value: next_url,
        rsvp_autoplay_value: autoplay,
        rsvp_progress_url_value: audiobook_chapter_progress_path(audiobook, chapter),
        rsvp_initial_progress_ms_value: initial_progress_ms
      }
    }
  end

  def rsvp_audio_attributes
    {
      preload: "metadata",
      class: "hidden",
      data: {
        rsvp_target: "audio",
        action: "play->rsvp#onPlay pause->rsvp#onPause seeked->rsvp#onSeeked loadedmetadata->rsvp#onLoadedMetadata"
      }
    }
  end
end
