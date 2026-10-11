module Paper::Publishable
  extend ActiveSupport::Concern

  included do
    has_one :publication, dependent: :destroy
    has_one :published_draft, through: :publication, source: :draft

    scope :published, -> { joins(:publication) }
    scope :unpublished, -> { where.missing(:publication) }
    scope :recently_published, -> { published.order(publications: { updated_at: :desc }) }
  end

  def published?
    publication.present?
  end

  def publish(draft = latest_draft)
    (publication || build_publication).update!(draft: draft)
  end

  def unpublish
    publication&.destroy
    self.publication = nil
  end
end
