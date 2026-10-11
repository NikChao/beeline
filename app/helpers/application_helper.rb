module ApplicationHelper
  # Pages the service worker should keep a copy of, so they open offline.
  def keep_offline(urls)
    content_for :head, tag.meta(name: "offline-pages", content: urls.to_json)
  end
end
