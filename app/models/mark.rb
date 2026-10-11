# A mark made with a pen over a draft. Coordinates are in page units: the page
# is 1000 units wide, so marks scale with the page instead of the viewport.
class Mark < ApplicationRecord
  KINDS = %w[ line stroke word ]
  COLORS = %w[ red green yellow ]
  MAX_POINTS = 2_000

  belongs_to :draft, touch: true

  validates :kind, inclusion: { in: KINDS }
  validates :color, inclusion: { in: COLORS }
  validates :text, presence: true, length: { maximum: 80 }, if: :word?
  validate :points_are_coordinates

  before_validation :normalize_points

  KINDS.each do |kind|
    define_method("#{kind}?") { self.kind == kind }
  end

  def path_data
    points.each_with_index.map { |point, index| "#{index.zero? ? "M" : "L"}#{point.map { format_number(it) }.join(" ")}" }.join(" ")
  end

  def origin
    points.first
  end

  private
    # Accepts [[x, y], ...] or the flat [x, y, x, y, ...] that forms send.
    def normalize_points
      self.points = Array(points).flatten.first(MAX_POINTS * 2).map { Float(it).round(1) }.each_slice(2).to_a
    rescue ArgumentError, TypeError
      self.points = []
    end

    def format_number(number)
      number.to_s.delete_suffix(".0")
    end

    def points_are_coordinates
      required = word? ? 1 : 2

      if points.size < required || points.any? { |point| point.size != 2 }
        errors.add(:points, "must have at least #{required} coordinates")
      end
    end
end
