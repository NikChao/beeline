require "test_helper"

class PaperTest < ActiveSupport::TestCase
  test "write starts a paper with its first draft" do
    paper = Paper.write(title: "Morning", author: "Ada", body: "<p>Coffee.</p>")

    assert_equal 1, paper.drafts.count
    assert_equal 1, paper.latest_draft.number
    assert_equal "Morning", paper.title
  end

  test "write keeps nothing when the draft is invalid" do
    assert_no_difference -> { Paper.count } do
      assert_raises(ActiveRecord::RecordInvalid) { Paper.write(title: "", body: "") }
    end
  end

  test "drafts are numbered in order" do
    draft = papers(:letter).draft(title: "A letter, finally", body: "<p>Third.</p>")

    assert_equal 3, draft.number
    assert_equal draft, papers(:letter).reload.latest_draft
    assert_equal drafts(:letter_second), draft.previous
  end

  test "publishing points the paper at a draft" do
    paper = papers(:letter)
    paper.publish(drafts(:letter_first))

    assert paper.published?
    assert_equal drafts(:letter_first), paper.reload.published_draft
    assert_includes Paper.published, paper

    paper.publish
    assert_equal drafts(:letter_second), paper.reload.published_draft
  end

  test "publishing right after a new draft publishes the new one" do
    paper = papers(:letter)
    paper.latest_draft
    draft = paper.draft(title: "A letter, finally", body: "<p>Third.</p>")
    paper.publish

    assert_equal draft, paper.reload.published_draft
  end

  test "unpublishing takes it off the shelf" do
    papers(:essay).unpublish

    assert_not papers(:essay).reload.published?
    assert_not_includes Paper.published, papers(:essay)
  end

  test "a paper can only publish its own drafts" do
    assert_raises(ActiveRecord::RecordInvalid) { papers(:letter).publish(drafts(:essay_first)) }
  end

  test "excerpts come from the paragraphs" do
    paper = Paper.write(title: "T", body: "<h2>Heading</h2><p>First  line.</p><ul><li>item</li></ul><p>Second.</p>")

    assert_equal "First line. Second.", paper.latest_draft.excerpt
  end
end
