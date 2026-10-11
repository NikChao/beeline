class Papers::PublicationsController < ApplicationController
  include PaperScoped

  def create
    @paper.publish(@paper.drafts.find(params[:draft_id]))
    redirect_to @paper
  end

  def destroy
    @paper.unpublish
    redirect_to paper_draft_path(@paper, @paper.latest_draft)
  end
end
