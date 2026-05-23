class Audiobook::Chapter::Word < ApplicationRecord
  include OptimalRecognitionPoint

  belongs_to :chapter, class_name: "Audiobook::Chapter"

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
    atoms.flat_map { |atom| split_compound_atom(atom) }
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
      .compact.map { |m| m.end(0) }.min
  end

  def self.playback_payload(scope = all)
    scope.pluck(:text, :start_time_ms, :orp_index).map { |text, start_ms, orp|
      { text: text, start: start_ms, orp: orp }
    }
  end

  def duration_ms
    end_time_ms - start_time_ms
  end
end
