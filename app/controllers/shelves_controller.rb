class ShelvesController < ApplicationController
  allow_unauthenticated_access

  def show
    @papers = Paper.recently_published.includes(:published_draft)
  end
end
