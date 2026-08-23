module SubscriptionsHelper
  # Sidebar sections: categorized groups first (sorted by
  # lowercased name, displayed with the first member's original casing),
  # then any uncategorized subscriptions as an unlabeled remainder.
  def subscription_nav_sections(subscriptions)
    categorized, rest = subscriptions.partition { |subscription| subscription.category.present? }
    sections = categorized
      .group_by { |subscription| subscription.category.downcase }
      .sort_by(&:first)
      .map { |_key, group| [ group.first.category, group ] }

    sections << [ nil, rest ] if rest.any?
    sections
  end

  def subscription_category_active?(name)
    params[:feed_id].blank? && params[:category].to_s.strip.casecmp?(name.to_s)
  end
end
