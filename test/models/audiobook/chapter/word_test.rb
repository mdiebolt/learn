require "test_helper"

class Audiobook::Chapter::WordTest < ActiveSupport::TestCase
  test "covering scope finds the word at a given timestamp" do
    chapter = audiobook_chapters(:one)
    word = chapter.words.covering(250).first

    assert_equal "Hello", word.text
  end

  test "covering scope returns the next word right at a boundary" do
    chapter = audiobook_chapters(:one)
    word = chapter.words.covering(500).first

    # 500ms is the start of "world" (and the end of "Hello"); end_time_ms is
    # exclusive so the boundary belongs to the next word.
    assert_equal "world", word.text
  end

  test "split_compound_atoms splits sentence-spanning tokens proportionally by character length" do
    atoms = Audiobook::Chapter::Word.split_compound_atoms([
      { "text" => "giving.Transactional", "start" => 1.0, "end" => 2.0 }
    ])

    assert_equal [ "giving.", "Transactional" ], atoms.map { _1["text"] }
    assert_in_delta 1.35, atoms[0]["end"], 0.01
    assert_in_delta 1.35, atoms[1]["start"], 0.01
  end

  test "split_compound_atoms handles a closing quote between the punctuation and the next word" do
    atoms = Audiobook::Chapter::Word.split_compound_atoms([
      { "text" => "Gift?\"Generosity", "start" => 0.0, "end" => 1.0 }
    ])

    assert_equal [ "Gift?\"", "Generosity" ], atoms.map { _1["text"] }
  end

  test "split_compound_atoms leaves abbreviations like U.S.A alone" do
    atoms = Audiobook::Chapter::Word.split_compound_atoms([
      { "text" => "U.S.A.", "start" => 0.0, "end" => 1.0 }
    ])

    assert_equal [ "U.S.A." ], atoms.map { _1["text"] }
  end

  test "split_compound_atoms handles multiple sentence breaks in one token" do
    atoms = Audiobook::Chapter::Word.split_compound_atoms([
      { "text" => "one.Two.Three", "start" => 0.0, "end" => 3.0 }
    ])

    assert_equal [ "one.", "Two.", "Three" ], atoms.map { _1["text"] }
  end

  test "split_compound_atoms splits camelCase merges when the trailing word is a sentence-starter" do
    atoms = Audiobook::Chapter::Word.split_compound_atoms([
      { "text" => "attendNow,", "start" => 0.0, "end" => 1.0 },
      { "text" => "couldIf", "start" => 1.0, "end" => 2.0 },
      { "text" => "recruitersIt", "start" => 2.0, "end" => 3.0 }
    ])

    assert_equal [ "attend", "Now,", "could", "If", "recruiters", "It" ],
      atoms.map { _1["text"] }
  end

  test "split_compound_atoms leaves legitimate camelCase tokens alone" do
    inputs = %w[McCord iPad YouTube LinkedIn DreamWorks DiLeonardo AgriGold ExxonMobil IAmWaldo]
    atoms = inputs.map { |t| { "text" => t, "start" => 0.0, "end" => 1.0 } }

    assert_equal inputs, Audiobook::Chapter::Word.split_compound_atoms(atoms).map { _1["text"] }
  end

  test "display_text strips sentence-context punctuation" do
    cases = {
      "world."          => "world",
      "however,"        => "however",
      "stop!"           => "stop",
      "first:"          => "first",
      "second;"         => "second",
      "\"Hello\""       => "Hello",
      "“Hello”" => "Hello",
      "(parenthesized)" => "parenthesized",
      "world.\""        => "world",
      "world.\")"       => "world"
    }
    cases.each do |input, expected|
      assert_equal expected, Audiobook::Chapter::Word.display_text(input), "input: #{input.inspect}"
    end
  end

  test "display_text keeps load-bearing punctuation" do
    %w[don't Matt's Gift-giving Harley-Davidson 1,000 50,000 2.5 U.S. e.g. Dr. Mr. Ph.D. J. and/or 24/7].each do |input|
      assert_equal input, Audiobook::Chapter::Word.display_text(input), "input: #{input.inspect}"
    end
  end

  test "display_text keeps trailing question marks while still stripping any surrounding quotes or brackets" do
    assert_equal "right?", Audiobook::Chapter::Word.display_text("right?")
    assert_equal "right?", Audiobook::Chapter::Word.display_text("right?\"")
    assert_equal "right?", Audiobook::Chapter::Word.display_text("right?)")
  end

  test "playback_payload renders display text and a matching ORP" do
    chapter = audiobook_chapters(:one)
    chapter.words.first.update!(text: "Hello.")

    entry = Audiobook::Chapter::Word.playback_payload(chapter.words).first

    assert_equal "Hello", entry[:text]
    assert_equal Audiobook::Chapter::Word.compute_orp_for("Hello"), entry[:orp]
  end
end
