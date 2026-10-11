require "test_helper"

class NativeLayoutTest < ActionDispatch::IntegrationTest
  NATIVE = "Mozilla/5.0 (iPhone) AppleWebKit/605.1.15 Beeline; Hotwire Native iOS; Turbo Native iOS;"

  test "browsers get the masthead and the app name in the title" do
    get papers_path

    assert_select "header.masthead"
    assert_select "title", "Desk · Beeline"
  end

  test "the app gets neither: its tabs and navigation bar do that job" do
    get papers_path, headers: { "User-Agent" => NATIVE }

    assert_select "header.masthead", count: 0
    assert_select "body.native"
    assert_select "title", "Desk"
  end

  test "pages save through the outbox, in the app and the browser alike" do
    get new_paper_path, headers: { "User-Agent" => NATIVE }
    assert_select "form.typewriter[data-offline=page]"

    get new_paper_draft_path(papers(:letter))
    assert_select "form.typewriter[data-offline=draft]"
  end
end
