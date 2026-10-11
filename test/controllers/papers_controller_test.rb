require "test_helper"

class PapersControllerTest < ActionDispatch::IntegrationTest
  test "locally, Beeline opens on the desk" do
    get root_path

    assert_select ".listing__heading", "On your desk"
  end

  test "shelf lists only published papers" do
    get shelf_path

    assert_response :success
    assert_select ".listing__title", text: "On paper"
    assert_select ".listing__title", text: /A letter/, count: 0
  end

  test "desk lists every paper" do
    get papers_path

    assert_select ".listing > .listing__items .listing__title", count: 2
  end

  test "saving a draft keeps it on the desk" do
    assert_difference -> { Paper.count } do
      post papers_path, params: { draft: { title: "Notes", author: "Ada", body: "<p>Hi.</p>" } }
    end

    paper = Paper.last
    assert_redirected_to paper_draft_path(paper, paper.latest_draft)
    assert_not paper.published?
    assert_equal "Ada", cookies[:author]
  end

  test "a replayed save finds the page it already made" do
    headers = { "Idempotency-Key" => "outbox-1" }

    assert_difference -> { Paper.count }, 1 do
      2.times { post papers_path, params: { draft: { title: "Once", body: "<p>Only once.</p>" } }, headers: headers }
    end
    assert_redirected_to paper_draft_path(Paper.last, Paper.last.latest_draft)
  end

  test "publishing puts it on the shelf" do
    post papers_path, params: { publish: "1", draft: { title: "Notes", body: "<p>Hi.</p>" } }

    assert_redirected_to paper_path(Paper.last)
    assert Paper.last.published?
  end

  test "saving without publishing" do
    post papers_path, params: { draft: { title: "Plain", body: "<p>One.</p><h1>Two</h1><ul><li>three</li></ul>" } }

    follow_redirect!
    assert_select ".page__body p", text: "One."
    assert_select ".page__body h1", text: "Two"
    assert_select ".page__body li", text: "three"
  end

  test "an empty page is sent back" do
    post papers_path, params: { draft: { title: "", body: "" } }

    assert_response :unprocessable_entity
    assert_select ".page__errors"
  end

  test "strikethrough survives saving" do
    post papers_path, params: { draft: { title: "Struck", body: "<p>Keep <s>cut this</s>.</p>" } }
    follow_redirect!

    assert_select ".page__body s", text: "cut this"
  end

  test "underline survives sanitizing" do
    get paper_path(papers(:essay))

    assert_select ".reading-page__body p u", text: "patient"
  end

  test "an unpublished paper opens on its latest draft" do
    get paper_path(papers(:letter))

    assert_redirected_to paper_draft_path(papers(:letter), drafts(:letter_second))
  end
end
