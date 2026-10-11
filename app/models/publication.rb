class Publication < ApplicationRecord
  belongs_to :paper, touch: true
  belongs_to :draft

  validate :draft_belongs_to_paper

  private
    def draft_belongs_to_paper
      errors.add(:draft, "must belong to the paper") unless draft&.paper_id == paper_id
    end
end
