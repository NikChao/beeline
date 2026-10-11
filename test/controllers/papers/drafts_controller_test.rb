require "test_helper"

class Papers::DraftsControllerTest < ActionDispatch::IntegrationTest
  test "show a draft with its marks" do
    get paper_draft_path(papers(:letter), drafts(:letter_first))

    assert_response :success
    assert_select "svg.marks path.mark--line.mark--red[d='M100 200 L300 200']"
  end

  test "new draft shows the previous one alongside" do
    get new_paper_draft_path(papers(:letter))

    assert_select ".desk__page--previous .page__title", text: "A letter, again"
    assert_select "#draft_title[value='A letter, again']"
  end

  test "write the next draft" do
    post paper_drafts_path(papers(:letter)), params: { draft: { title: "A letter, finally", body: "<p>Third.</p>" } }

    draft = papers(:letter).latest_draft
    assert_equal 3, draft.number
    assert_redirected_to paper_draft_path(papers(:letter), draft)
  end

  test "a replayed draft isn't written twice" do
    headers = { "Idempotency-Key" => "outbox-2" }

    assert_difference -> { papers(:letter).drafts.count }, 1 do
      2.times { post paper_drafts_path(papers(:letter)), params: { draft: { title: "Again", body: "<p>Third.</p>" } }, headers: headers }
    end
  end

  test "write and publish the next draft" do
    post paper_drafts_path(papers(:essay)), params: { publish: "1", draft: { title: "On paper", body: "<p>Still patient.</p>" } }

    assert_redirected_to paper_path(papers(:essay))
    assert_equal 2, papers(:essay).reload.published_draft.number
  end

  test "publish and unpublish a draft" do
    post paper_publication_path(papers(:letter), draft_id: drafts(:letter_first))
    assert_equal drafts(:letter_first), papers(:letter).reload.published_draft

    delete paper_publication_path(papers(:letter))
    assert_not papers(:letter).reload.published?
  end
end
