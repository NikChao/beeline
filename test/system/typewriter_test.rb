require "application_system_test_case"

class TypewriterTest < ApplicationSystemTestCase
  test "type a page, without going back, and publish it" do
    visit new_paper_path

    fill_in "Title", with: "Morning pages"
    fill_in "Author", with: "Ada"

    body = find(".lexxy-editor__content")
    body.click
    body.send_keys "Coffeee", :backspace, :backspace, :delete
    body.send_keys :enter, "# A heading", :enter, "- one", :enter, "two"

    assert_selector ".lexxy-editor__content p", text: "Coffeee"
    assert_selector ".lexxy-editor__content h1", text: "A heading"
    assert_selector ".lexxy-editor__content ul li", count: 2

    click_on "Publish"

    assert_selector ".reading-page__title", text: "Morning pages"
    assert_selector ".reading-page__body p", text: "Coffeee"
    assert_selector ".reading-page__body h1", text: "A heading"
    assert_selector ".reading-page__body li", text: "two"

    visit root_path
    assert_selector ".listing__title", text: "Morning pages"
  end

  test "selected text can be formatted but not typed over or cut" do
    visit new_paper_path
    fill_in "Title", with: "Formats"

    body = find(".lexxy-editor__content")
    body.click
    body.send_keys "plain bold"
    body.send_keys [ :shift, :left ], [ :shift, :left ], [ :shift, :left ], [ :shift, :left ]
    assert_selected "bold"
    body.send_keys [ :control, "b" ]
    body.send_keys "x"
    body.send_keys [ :control, "x" ]
    body.send_keys [ :control, "z" ]

    assert_selector ".lexxy-editor__content", text: "plain bold"
    assert_selector ".lexxy-editor__content strong, .lexxy-editor__content b", text: "bold"

    body.send_keys :right, " ", [ :control, "u" ], "under"
    click_on "Save as draft"

    assert_selector ".page__body b, .page__body strong", text: "bold"
    assert_selector ".page__body u", text: "under"
  end

  test "strike words through with Ctrl Shift X" do
    visit new_paper_path
    fill_in "Title", with: "Struck"

    body = find(".lexxy-editor__content")
    body.click
    body.send_keys "keep cut"
    3.times { body.send_keys [ :shift, :left ] }
    assert_selected "cut"
    body.send_keys [ :control, :shift, "x" ]

    assert_selector ".lexxy-editor__content", text: "keep cut" # not cut out
    assert_selector ".lexxy-editor__content .lexxy-content__strikethrough", text: "cut"

    click_on "Save as draft"
    assert_selector ".page__body s", text: "cut"
  end

  test "on a touch screen, selected words get a format bar" do
    visit new_paper_path
    execute_script "const real = window.matchMedia.bind(window); window.matchMedia = query => query.includes('coarse') ? { matches: true } : real(query)"
    fill_in "Title", with: "Touch"

    body = find(".lexxy-editor__content")
    body.click
    body.send_keys "one two"
    assert_no_selector ".format-bar"

    3.times { body.send_keys [ :shift, :left ] }
    assert_selected "two"
    assert_selector ".format-bar"

    find(".format-bar__button[aria-label=Strikethrough]").click
    assert_selector ".lexxy-editor__content .lexxy-content__strikethrough", text: "two"
    assert_selector ".format-bar__button[aria-label=Strikethrough][aria-pressed=true]"
    assert_selected "two" # the selection stays put

    body.send_keys :right
    assert_no_selector ".format-bar"
  end

  test "markdown beyond headings and bullets stays prose" do
    visit new_paper_path
    fill_in "Title", with: "Plain"

    body = find(".lexxy-editor__content")
    body.click
    body.send_keys "> quoted", :enter, :enter, "1. numbered", :enter, :enter, "```"
    body.send_keys :enter, "code"

    assert_no_selector ".lexxy-editor__content blockquote"
    assert_no_selector ".lexxy-editor__content ol"
    assert_no_selector ".lexxy-editor__content pre, .lexxy-editor__content code"
    assert_selector ".lexxy-editor__content", text: "quoted"
    assert_selector ".lexxy-editor__content", text: "numbered"
  end

  test "mark up a draft and write the next one beside it" do
    visit paper_draft_path(papers(:letter), drafts(:letter_second))

    page_box = find(".page")
    assert_selector ".tray__tool[aria-pressed=true]", text: "Marker"
    tap page_box, at: [ 200, 300 ] # just a click: no mark
    draw page_box, from: [ 120, 300 ], to: [ 400, 300 ]
    assert_selector "svg.marks path.mark--line.mark--red"

    click_on "Pen"
    find(".tray__color--green").click
    draw page_box, from: [ 150, 500 ], to: [ 300, 560 ]
    assert_selector "svg.marks path.mark--stroke.mark--green"

    click_on "Word"
    tap page_box, at: [ 420, 450 ]
    find(".marks__word-input").send_keys "tighter", :enter
    assert_selector "svg.marks text.mark--word", text: "tighter"

    # Marks are drawn at once, and reach the server through the outbox.
    assert_no_selector ".sync-status", visible: true
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.05 until drafts(:letter_second).marks.count == 3 }
    refresh
    assert_selector "svg.marks .mark", count: 3

    click_on "Write draft 3"
    click_on "Beside draft 2"
    assert_selector ".desk--split .desk__page--previous .page__title", text: "A letter, again"
    assert_selector ".desk__page--previous svg.marks .mark", count: 3

    find(".lexxy-editor__content").click
    find(".lexxy-editor__content").send_keys "Dear reader, the third try."
    click_on "Save as draft"

    assert_selector ".draft__version[aria-current=page]", text: "Draft 3"
    assert_selector ".page__body", text: "the third try"
  end

  private
    def assert_selected(text)
      Timeout.timeout(Capybara.default_max_wait_time) do
        sleep 0.05 until page.evaluate_script("window.getSelection().toString()") == text
      end
    end

    def tap(element, at:)
      page.driver.browser.action.move_to(element.native, *offset(element, at)).click.perform
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
end
