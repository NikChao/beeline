require "test_helper"

class OutboxesControllerTest < ActionDispatch::IntegrationTest
  test "the outbox page is there for the service worker to keep" do
    get outbox_path

    assert_response :success
    assert_select "[data-controller=outbox] template"
  end

  test "the service worker and manifest are served" do
    get pwa_service_worker_path(format: :js)
    assert_response :success

    get pwa_manifest_path(format: :json)
    assert_equal "Beeline", response.parsed_body["name"]
  end
end
