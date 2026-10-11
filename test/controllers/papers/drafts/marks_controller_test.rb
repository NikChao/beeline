require "test_helper"

class Papers::Drafts::MarksControllerTest < ActionDispatch::IntegrationTest
  test "make a mark" do
    assert_difference -> { drafts(:letter_first).marks.count } do
      post paper_draft_marks_path(papers(:letter), drafts(:letter_first)),
        params: { mark: { kind: "word", color: "green", points: [ 120, 340 ], text: "tighter" } }, as: :json
    end

    assert_response :created
    assert_equal Mark.last.id, response.parsed_body["id"]
  end

  test "a replayed mark is made once" do
    path = paper_draft_marks_path(papers(:letter), drafts(:letter_first))
    mark = { kind: "line", color: "red", points: [ 1, 1, 9, 1 ] }

    assert_difference -> { Mark.count }, 1 do
      2.times { post path, params: { mark: mark }, headers: { "Idempotency-Key" => "outbox-3" }, as: :json }
    end
  end

  test "a bad mark is refused" do
    post paper_draft_marks_path(papers(:letter), drafts(:letter_first)),
      params: { mark: { kind: "line", color: "purple", points: [ 1, 1, 2, 2 ] } }, as: :json

    assert_response :unprocessable_entity
  end

  test "take a mark back" do
    assert_difference -> { Mark.count }, -1 do
      delete paper_draft_mark_path(papers(:letter), drafts(:letter_first), marks(:strike))
    end
  end
end
