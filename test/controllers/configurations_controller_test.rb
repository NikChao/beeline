require "test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "path configuration for the iOS app" do
    get ios_configuration_path(format: :json)

    rules = response.parsed_body["rules"]
    assert_equal "modal", rules.find { it["patterns"] == [ "/new$" ] }.dig("properties", "context")
    assert_equal false, rules.find { it["patterns"] == [ "/drafts/\\d+$" ] }.dig("properties", "pull_to_refresh_enabled")
  end
end
