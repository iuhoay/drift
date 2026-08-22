json.(entry, :id, :title, :url)
json.published_at entry.published_at&.iso8601
json.read user_entry&.read? || false
json.starred user_entry&.starred? || false
json.feed do
  json.id entry.feed_id
  json.title entry.feed.display_title
end

if local_assigns[:detail]
  json.author entry.author
  json.has_full_content entry.full_content.present?
  json.body entry.plain_body
else
  json.excerpt entry.excerpt
end
