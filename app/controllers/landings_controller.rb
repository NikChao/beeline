class LandingsController < ApplicationController
  allow_unauthenticated_access

  layout "landing"

  def show
    @download = Dir[Rails.public_path.join("downloads/Beeline-*.dmg")].max_by { File.mtime(it) }
  end
end
