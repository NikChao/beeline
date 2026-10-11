class Papers::DraftsController < ApplicationController
  include PaperScoped

  def show
    @draft = @paper.drafts.find(params[:id])
  end

  def new
    @previous = @paper.latest_draft
    @draft = @paper.drafts.build(title: @previous.title, author: @previous.author)
  end

  def create
    @draft = @paper.draft(draft_params)
    @paper.publish(@draft) if params[:publish]

    redirect_to params[:publish] ? paper_path(@paper) : paper_draft_path(@paper, @draft)
  rescue ActiveRecord::RecordInvalid => invalid
    @draft = invalid.record
    @previous = @paper.latest_draft
    render :new, status: :unprocessable_entity
  end

  private
    def draft_params
      params.expect(draft: %i[ title author body ])
    end
end
