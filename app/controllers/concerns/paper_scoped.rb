module PaperScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_paper
  end

  private
    def set_paper
      @paper = Paper.find(params[:paper_id])
    end
end
