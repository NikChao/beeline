class ShelvesController < ApplicationController
  def show
    @papers = Paper.recently_published.includes(:published_draft)
  end
end
