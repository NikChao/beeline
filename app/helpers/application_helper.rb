module ApplicationHelper
  # Native apps show the page name in their navigation bar; browsers get the app name too.
  def page_title
    hotwire_native_app? ? content_for(:title) : [ content_for(:title), "Beeline" ].compact_blank.join(" · ")
  end

  # Pages the service worker should keep a copy of, so they open offline.
  def keep_offline(urls)
    content_for :head, tag.meta(name: "offline-pages", content: urls.to_json)
  end
end
