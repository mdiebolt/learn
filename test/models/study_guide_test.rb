require "test_helper"

class StudyGuideTest < ActiveSupport::TestCase
  setup do
    @chapter = chapters(:one)
    @user = users(:one)
  end

  def payload(*topics)
    JSON.generate(topics: topics)
  end

  test "persists topics, cards, and visuals from a well-formed payload" do
    raw = payload(
      {
        type: "card",
        kind: "multiple_choice",
        concept_title: "Mitochondria",
        source_excerpt: "powerhouse of the cell",
        attributes: { question: "What is the powerhouse of the cell?", options: %w[Nucleus Mitochondria Ribosome], correct_index: 1 }
      },
      { type: "visual", kind: "timeline", caption: "Cell evolution", attributes: { events: [ { when: "1.5B BCE", label: "First eukaryote" } ] } }
    )

    guide = StudyGuide.create_from_ai_payload!(chapter: @chapter, user: @user, raw_response: raw, model: "claude-test")

    assert_equal 2, guide.topics.size
    assert_equal [ "Card", "Visual" ], guide.topics.map(&:topical_type)
    assert_equal 1, guide.cards.size
    assert_equal 1, guide.visuals.size
    assert_equal "claude-test", guide.model
  end

  test "strips ```json fences around the payload" do
    raw = "```json\n#{payload(type: "card", kind: "free_response", concept_title: "X", attributes: { question: "Q", reference_answer: "A" })}\n```"

    guide = StudyGuide.create_from_ai_payload!(chapter: @chapter, user: @user, raw_response: raw, model: "claude-test")

    assert_equal 1, guide.topics.size
  end

  test "raises on malformed JSON without persisting a guide" do
    assert_no_difference -> { StudyGuide.count } do
      assert_raises(JSON::ParserError) do
        StudyGuide.create_from_ai_payload!(chapter: @chapter, user: @user, raw_response: "not json at all", model: "claude-test")
      end
    end
  end

  test "empty topics array raises EmptyGeneration and rolls back the guide" do
    assert_no_difference -> { StudyGuide.count } do
      assert_raises(StudyGuide::EmptyGeneration) do
        StudyGuide.create_from_ai_payload!(chapter: @chapter, user: @user, raw_response: payload, model: "claude-test")
      end
    end
  end

  test "drops a single invalid topic while keeping the rest" do
    raw = payload(
      { type: "card", kind: "multiple_choice", concept_title: "Bad", attributes: { question: "" } },
      { type: "card", kind: "multiple_choice", concept_title: "Good", attributes: { question: "Q", options: %w[a b], correct_index: 0 } }
    )

    guide = StudyGuide.create_from_ai_payload!(chapter: @chapter, user: @user, raw_response: raw, model: "claude-test")

    assert_equal 1, guide.topics.size
    assert_equal "Good", guide.cards.first.concept_title
  end

  test "drops topics with an unknown type instead of aborting the batch" do
    raw = payload(
      { type: "unknown", kind: "whatever" },
      { type: "visual", kind: "diagram", caption: "X", attributes: { nodes: [ { id: 1, label: "a" } ], edges: [ { from: 1, to: 1, label: "self" } ] } }
    )

    guide = StudyGuide.create_from_ai_payload!(chapter: @chapter, user: @user, raw_response: raw, model: "claude-test")

    assert_equal 1, guide.topics.size
    assert_equal "Visual::Diagram", guide.visuals.first.kind_type
  end
end
