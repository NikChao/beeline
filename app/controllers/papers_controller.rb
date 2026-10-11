class PapersController < ApplicationController
  before_action :set_paper, only: %i[ show destroy ]

  def index
    @papers = Paper.latest.includes(:latest_draft, :publication)
  end

  def show
    if @paper.published?
      @draft = @paper.published_draft
    else
      redirect_to paper_draft_path(@paper, @paper.latest_draft)
    end
  end

  def new
    @draft = Draft.new(author: cookies[:author])
  end

  def create
    @draft = Draft.saved_with(client_key) || Paper.write(draft_params.merge(client_key: client_key)).latest_draft
    @paper = @draft.paper
    remember_author

    if params[:publish]
      @paper.publish(@draft)
      redirect_to @paper
    else
      redirect_to paper_draft_path(@paper, @draft)
    end
  rescue ActiveRecord::RecordInvalid => invalid
    @draft = invalid.record
    render :new, status: :unprocessable_entity
  end

  def destroy
    @paper.destroy
    redirect_to papers_path
  end

  private
    def set_paper
      @paper = Paper.find(params[:id])
    end

    def draft_params
      params.expect(draft: %i[ title author body ])
    end

    def remember_author
      cookies.permanent[:author] = draft_params[:author] if draft_params[:author].present?
    end
end
