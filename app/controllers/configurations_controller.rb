# Navigation rules for the Hotwire Native app. The app bundles a copy
# (ios/Beeline/path-configuration.json) and loads this one over it.
class ConfigurationsController < ApplicationController
  def ios_v1
    render json: {
      settings: {},
      rules: [
        {
          patterns: [ ".*" ],
          properties: { context: "default", pull_to_refresh_enabled: true }
        },
        {
          patterns: [ "/new$" ],
          properties: { context: "modal", modal_style: "full", pull_to_refresh_enabled: false },
          comment: "Type a new page or draft full screen."
        },
        {
          patterns: [ "/drafts/\\d+$" ],
          properties: { pull_to_refresh_enabled: false },
          comment: "Pulling down would fight the pen."
        }
      ]
    }
  end
end
