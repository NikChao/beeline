class Papers::Drafts::MarksController < ApplicationController
  include DraftScoped

  def create
    @mark = @draft.marks.saved_with(client_key) || @draft.marks.create!(mark_params.merge(client_key: client_key))
    render json: { id: @mark.id }, status: :created
  rescue ActiveRecord::RecordInvalid => invalid
    render json: { errors: invalid.record.errors.full_messages }, status: :unprocessable_entity
  end

  def destroy
    @draft.marks.find(params[:id]).destroy
    head :no_content
  end

  private
    def mark_params
      params.expect(mark: [ :kind, :color, :text, points: [] ])
    end
end
