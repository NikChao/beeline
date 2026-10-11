# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

# Served from a sub-path (e.g. example.com/write) when RAILS_RELATIVE_URL_ROOT is set.
map Rails.application.config.relative_url_root.presence || "/" do
  run Rails.application
end
Rails.application.load_server
