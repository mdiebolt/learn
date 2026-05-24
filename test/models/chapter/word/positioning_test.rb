require "test_helper"

class Chapter::Word::PositioningTest < ActiveSupport::TestCase
  Word = Chapter::Word

  def build(text)
    Word.new(text: text, start_time_ms: 0, end_time_ms: 1, position: 0)
  end

  test "1-letter words have ORP at index 0" do
    assert_equal 0, build("I").compute_orp_index
  end

  test "2-5 letter words have ORP at index 1" do
    assert_equal 1, build("at").compute_orp_index
    assert_equal 1, build("hello").compute_orp_index
  end

  test "6-9 letter words have ORP at index 2" do
    assert_equal 2, build("animal").compute_orp_index
    assert_equal 2, build("recovery").compute_orp_index
  end

  test "10-13 letter words have ORP at index 3" do
    assert_equal 3, build("understand").compute_orp_index
    assert_equal 3, build("transcribers").compute_orp_index
  end

  test "14+ letter words have ORP at index 4" do
    assert_equal 4, build("internationalize").compute_orp_index
  end

  test "non-alphabetic characters are ignored when sizing the word" do
    # "I'm" has 2 alphabetic characters → ORP at index 1
    assert_equal 1, build("I'm").compute_orp_index
  end

  test "orp_index is assigned on create from text" do
    chapter = chapters(:one)
    word = chapter.words.create!(
      text: "wonderful", start_time_ms: 0, end_time_ms: 1, position: 99
    )

    # 9 alphabetic chars → index 2
    assert_equal 2, word.orp_index
  end

  test "before_orp / at_orp / after_orp slice the text correctly" do
    word = build("hello").tap { it.orp_index = it.compute_orp_index }

    assert_equal "h",   word.before_orp
    assert_equal "e",   word.at_orp
    assert_equal "llo", word.after_orp
  end
end
