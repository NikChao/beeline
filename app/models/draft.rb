class Draft < ApplicationRecord
  include ClientKeyed

  belongs_to :paper, touch: true
  has_many :marks, -> { order(:id) }, dependent: :destroy
  has_rich_text :body

  validates :title, presence: true
  validates :body, presence: true

  before_validation :assign_number, on: :create

  def previous
    paper.drafts.where(number: ...number).last
  end

  def excerpt(length: 200)
    prose = body.body.fragment.find_all("p").map { it.text.squish }.join(" ")
    prose.truncate(length, separator: " ")
  end

  def latest?
    self == paper.latest_draft
  end

  def published?
    paper.published_draft == self
  end

  private
    def assign_number
      self.number ||= (paper.drafts.maximum(:number) || 0) + 1
    end
end
