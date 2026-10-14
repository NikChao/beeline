require "application_system_test_case"

class OfflineTest < ApplicationSystemTestCase
  test "a page saved without the host waits on this device, then syncs" do
    visit new_paper_path
    lose_the_host

    fill_in "Title", with: "Kept on a train"
    type "No host in sight."
    click_on "Publish"

    # Optimistic: it's on the shelf straight away, marked as waiting.
    assert_selector ".listing__heading", text: "On the shelf"
    assert_selector ".listing__item--pending .listing__title", text: "Kept on a train"
    assert_selector ".listing__item--pending .listing__meta", text: "waiting to sync"
    assert_selector ".sync-status", text: "1 waiting to sync"
    assert_not Draft.exists?(title: "Kept on a train")

    # Then the server has it, and the shelf is fetched again.
    find_the_host
    assert_no_selector ".sync-status", visible: true
    assert_no_selector ".listing__item--pending"
    assert_selector ".listing > .listing__items .listing__title", text: "Kept on a train"

    draft = Draft.find_by!(title: "Kept on a train")
    assert draft.published?
    assert_equal "No host in sight.", draft.body.to_plain_text
  end

  test "a draft saved without the host waits on the desk" do
    visit new_paper_path
    lose_the_host

    fill_in "Title", with: "Desk bound"
    type "- Not yet."
    click_on "Save as draft"

    assert_selector ".listing__heading", text: "On your desk"
    assert_selector ".listing__item--pending .listing__meta", text: "New page · waiting to sync"

    # It reads as a page, formatting and all, until the server has it.
    click_on "Desk bound"
    assert_selector ".listing__heading", text: "Outbox"
    assert_selector ".outbox__page .page__title", text: "Desk bound"
    assert_selector ".outbox__page .page__body ul li", text: "Not yet."
  end

  test "marks made without the host stay on the page wherever it's shown" do
    draft = drafts(:letter_second)
    visit paper_draft_path(papers(:letter), draft)
    lose_the_host

    page_box = find(".page")
    draw page_box, from: [ 120, 300 ], to: [ 400, 300 ]
    assert_selector "svg.marks path.mark--line"
    assert_selector ".sync-status", text: "1 waiting to sync"

    # Away and back: the page as served doesn't have it, the outbox does.
    execute_script "Turbo.visit(#{papers_path.to_json})"
    assert_selector ".listing"
    execute_script "Turbo.visit(#{paper_draft_path(papers(:letter), draft).to_json})"
    assert_selector ".page__title", text: draft.title
    assert_selector "svg.marks path.mark--line", count: 1

    click_on "Write draft 3"
    click_on "Beside draft 2"
    assert_selector ".desk__page--previous svg.marks path.mark--line", count: 1

    find_the_host
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.05 until draft.marks.count == 1 }
  end

  test "what's being typed is kept on this device" do
    visit new_paper_path
    fill_in "Title", with: "Half finished"
    type "A thought, interrupted"

    accept_confirm { click_on "Desk" }
    visit new_paper_path

    assert_field "Title", with: "Half finished"
    assert_selector ".lexxy-editor__content", text: "A thought, interrupted"
  end

  test "an empty page isn't saved" do
    visit new_paper_path
    fill_in "Title", with: "Nothing yet"
    click_on "Save as draft"

    assert_selector ".page__errors", text: "Type something on the page first."
    assert_current_path new_paper_path
  end

  private
    def type(text)
      find(".lexxy-editor__content").click
      find(".lexxy-editor__content").send_keys text
    end

    # Saves fail as they would with the host out of reach; pages still load.
    def lose_the_host
      execute_script <<~JS
        window.realFetch ||= window.fetch
        window.fetch = (input, init = {}) =>
          (init.method || "GET").toUpperCase() === "POST" ? Promise.reject(new TypeError("Load failed")) : window.realFetch(input, init)
      JS
    end

    def draw(element, from:, to:)
      page.driver.browser.action
        .move_to(element.native, *offset(element, from)).click_and_hold
        .move_to(element.native, *offset(element, from.zip(to).map { |a, b| (a + b) / 2 }))
        .move_to(element.native, *offset(element, to)).release.perform
    end

    # Selenium offsets are from the element's center.
    def offset(element, (x, y))
      rect = element.native.rect
      [ (x - rect.width / 2).round, (y - rect.height / 2).round ]
    end

    def find_the_host
      execute_script "window.fetch = window.realFetch; window.dispatchEvent(new Event('online'))"
    end
end
