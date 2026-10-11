require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { Rails.configuration.x.authentication = true }
  teardown { Rails.configuration.x.authentication = false }

  test "the desk asks you to sign in, and brings you back after" do
    get papers_path
    assert_redirected_to new_session_path

    sign_in "ada@example.com"
    assert_redirected_to papers_url

    follow_redirect!
    assert_select ".listing__heading", "On your desk"
  end

  test "the shelf and published pages stay public" do
    get shelf_path
    assert_response :success

    get paper_path(papers(:essay))
    assert_select ".reading-page__title", "On paper"
  end

  test "something that isn't an email address gets no email" do
    assert_no_enqueued_emails do
      post session_path, params: { email_address: "not an email" }
    end
    assert_redirected_to new_session_code_path

    post session_code_path, params: { code: "123456" }
    assert_response :unprocessable_entity
  end

  test "each writer's desk is their own" do
    sign_in "ada@example.com"
    post papers_path, params: { draft: { title: "Ada's", body: "<p>Mine.</p>" } }
    adas = Paper.last
    assert_equal "ada@example.com", adas.user.email_address

    delete session_path
    sign_in "grace@example.com"

    get papers_path
    assert_select ".listing > .listing__items .listing__title", count: 0
    get paper_draft_path(adas, adas.latest_draft)
    assert_response :not_found
    delete paper_path(adas)
    assert_response :not_found
    post paper_publication_path(adas, draft_id: adas.latest_draft)
    assert_response :not_found
    assert Paper.exists?(adas.id)
  end

  test "everyone's published papers are on the shelf" do
    sign_in "ada@example.com"
    post papers_path, params: { publish: "1", draft: { title: "Ada in print", body: "<p>Read me.</p>" } }
    delete session_path

    get shelf_path
    assert_select ".listing__title", text: "Ada in print"
    get paper_path(Paper.last)
    assert_select ".reading-page__title", "Ada in print"
  end

  # Mail that the server refuses, as Resend does for addresses it won't send to.
  class RefusedDelivery
    def initialize(*) = nil
    def deliver!(*) = raise(Net::SMTPFatalError.new("550 You can only send testing emails to your own email address"))
  end
  ActionMailer::Base.add_delivery_method :refused, RefusedDelivery

  test "a refused address is said out loud" do
    ActionMailer::Base.delivery_method = :refused
    post session_path, params: { email_address: "alex@example.com" }

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select ".sign-in__alert", /couldn't email a code/
  ensure
    ActionMailer::Base.delivery_method = :test
  end

  test "asking twice in a row sends one code" do
    assert_emails 1 do
      2.times { post session_path, params: { email_address: "ada@example.com" } }
    end
    assert_redirected_to new_session_code_path
  end

  test "a wrong code doesn't sign you in" do
    post session_path, params: { email_address: "ada@example.com" }
    post session_code_path, params: { code: "not it" }

    assert_response :unprocessable_entity
    get papers_path
    assert_redirected_to new_session_path
  end

  test "the outbox and the app are told, not redirected" do
    post papers_path, params: { draft: { title: "T", body: "<p>B</p>" } }, headers: { "Idempotency-Key" => "k" }
    assert_response :unauthorized

    get papers_path, headers: { "User-Agent" => "Beeline; Hotwire Native iOS; Turbo Native iOS;" }
    assert_response :unauthorized
  end

  test "signing out" do
    sign_in "ada@example.com"
    delete session_path

    get papers_path
    assert_redirected_to new_session_path
  end

  private
    def sign_in(email_address)
      post session_path, params: { email_address: email_address }
      code = ActionMailer::Base.deliveries.last.subject[/\d{6}/]
      post session_code_path, params: { code: code }
    end
end
