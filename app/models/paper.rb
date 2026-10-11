class Paper < ApplicationRecord
  include Publishable

  has_many :drafts, -> { order(:number) }, dependent: :destroy
  has_one :latest_draft, -> { order(number: :desc) }, class_name: "Draft"

  scope :latest, -> { order(updated_at: :desc) }

  delegate :title, :author, to: :latest_draft, allow_nil: true

  def self.write(attributes)
    transaction do
      create!.tap { |paper| paper.drafts.create!(attributes) }
    end
  end

  def draft(attributes)
    drafts.create!(attributes).tap { reset_latest_draft }
  end
end
