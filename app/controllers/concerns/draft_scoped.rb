module DraftScoped
  extend ActiveSupport::Concern

  included do
    include PaperScoped
    before_action :set_draft
  end

  private
    def set_draft
      @draft = @paper.drafts.find(params[:draft_id])
    end
end
