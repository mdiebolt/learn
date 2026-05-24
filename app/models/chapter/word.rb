class Chapter::Word < ApplicationRecord
  include OptimalRecognitionPoint

  belongs_to :chapter

  default_scope { order(:position) }

  scope :covering, ->(time_ms) {
    where("start_time_ms <= ? AND end_time_ms > ?", time_ms, time_ms)
  }

  # Scribe occasionally returns two sentences as a single token when the
  # speaker doesn't pause between them — e.g. "giving.Transactional" or
  # "Gift?\"Generosity". Match an internal sentence-terminal punct (optionally
  # followed by a closing quote/paren/bracket) that's preceded by a lowercase
  # letter or digit and followed by an uppercase letter, so abbreviations like
  # "U.S.A" are left alone.
  SENTENCE_BREAK = /[a-z0-9][.!?]["')\]]?(?=[[:upper:]])/

  # Same upstream behaviour but with no punctuation between the two words —
  # e.g. "attendNow," for "attend. Now,". A blind [a-z][A-Z] split would
  # destroy legitimate camelCase (McCord, iPad, YouTube, DiLeonardo), so only
  # split when the trailing word is a common sentence-starting function word.
  # English proper nouns essentially never start with these, so the false-
  # positive risk is negligible; extend the list as new bug cases surface.
  CAMEL_SENTENCE_STARTERS = %w[
    I It Its They Their Them This That These Those There Then
    When Where Why While Who Whose Whom We You Your
    He She His Her My Our Now And But So If Although Even Each
  ].freeze

  CAMEL_SENTENCE_BREAK = /[a-z](?=(?:#{CAMEL_SENTENCE_STARTERS.join('|')})(?:[^A-Za-z]|$))/

  def self.split_compound_atoms(atoms)
    atoms.flat_map { split_compound_atom(it) }
  end

  def self.split_compound_atom(atom)
    text = atom["text"].to_s
    split_at = first_split_index(text)
    return [ atom ] unless split_at

    head = text[0...split_at]
    tail = text[split_at..]
    start_s = atom["start"].to_f
    end_s = atom["end"].to_f
    mid_s = start_s + (end_s - start_s) * (head.length.to_f / text.length)

    [
      atom.merge("text" => head, "start" => start_s, "end" => mid_s),
      *split_compound_atom(atom.merge("text" => tail, "start" => mid_s, "end" => end_s))
    ]
  end

  def self.first_split_index(text)
    [ SENTENCE_BREAK.match(text), CAMEL_SENTENCE_BREAK.match(text) ]
      .compact.map { it.end(0) }.min
  end

  # Words whose trailing period is part of the word's identity rather than
  # sentence punctuation. Extend as needed; the goal is "almost never wrong",
  # not "exhaustive". Compared case-insensitively against the period-stripped
  # body so "Dr.", "Mr.", "etc." all hit.
  ABBREVIATIONS_WITH_TRAILING_PERIOD = %w[
    Dr Mr Mrs Ms Jr Sr St Prof Rev Hon Capt Lt Sgt Gen Esq
    Inc Ltd Co Corp Ave Blvd Rd Vol Vs Etc
  ].map(&:downcase).to_set.freeze

  LEADING_PUNCTUATION = /\A[(\[{"“]+/
  TRAILING_PUNCTUATION = /[,;:!"”)\]}]+\z/

  # Strip sentence-context punctuation so the focal word reads cleanly. Keep
  # anything that belongs to the token itself: contractions ("don't"),
  # possessives ("Matt's"), hyphenations ("Gift-giving"), numbers ("1,000"),
  # abbreviations ("Dr.", "U.S."), and initials ("J.").
  def self.display_text(text)
    previous = nil
    current = text.to_s
    until previous == current
      previous = current
      current = current.sub(LEADING_PUNCTUATION, "").sub(TRAILING_PUNCTUATION, "")
      current = current.chomp(".") if strippable_trailing_period?(current)
    end
    current
  end

  def self.strippable_trailing_period?(text)
    return false unless text.end_with?(".")
    body = text.chomp(".")
    return false if body.empty?
    return false if body.include?(".")
    return false if body.match?(/\A[A-Z]\z/)
    !ABBREVIATIONS_WITH_TRAILING_PERIOD.include?(body.downcase)
  end

  def self.playback_payload(scope = all)
    scope.pluck(:text, :start_time_ms).filter_map { |text, start_ms|
      display = display_text(text)
      next if display.empty?
      { text: display, start: start_ms, orp: compute_orp_for(display) }
    }
  end

  def duration_ms
    end_time_ms - start_time_ms
  end
end
