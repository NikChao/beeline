require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Beeline
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # BEELINE_MODE=local (the default): open to whoever can reach it, and
    # straight to the desk, as on a home network.
    # BEELINE_MODE=prod: a public server, with email sign-in and a landing page.
    config.x.mode = ActiveSupport::StringInquirer.new(ENV.fetch("BEELINE_MODE", "local").downcase)
    config.x.authentication = config.x.mode.prod?
    config.x.landing = config.x.mode.prod?
    config.x.host = ENV["BEELINE_HOST"]
    config.x.email_delivery = true # production needs RESEND_API_KEY; see production.rb

    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
