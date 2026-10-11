require "test_helper"

class LandingsControllerTest < ActionDispatch::IntegrationTest
  test "the landing page links to the web app" do
    get landing_path

    assert_response :success
    assert_select ".landing__name", "Beeline"
    assert_select "a[href=?]", shelf_path, text: "Write in your browser"
  end

  test "it offers the newest Mac app, when there is one" do
    downloads = Rails.public_path.join("downloads")
    FileUtils.mkdir_p(downloads)
    FileUtils.touch(downloads.join("Beeline-test.dmg"))

    get landing_path
    assert_select "a[download=?][href$=?]", "Beeline.dmg", "downloads/Beeline-test.dmg", text: "Download for Mac"
  ensure
    FileUtils.rm_f(downloads.join("Beeline-test.dmg"))
  end

  test "www redirects to the bare domain" do
    Rails.configuration.x.host = "beeline.ink"
    host! "www.beeline.ink"
    get "/papers?x=1"

    assert_redirected_to "http://beeline.ink/papers?x=1"
    assert_response :moved_permanently
  ensure
    Rails.configuration.x.host = nil
  end
end
