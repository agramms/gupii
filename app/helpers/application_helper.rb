module ApplicationHelper
  # Generate navigation links with proper subpath support and styling
  def nav_link(path, icon, text, active: false)
    # Ensure path includes subpath in development
    Rails.logger.info "🔍 NAV_LINK CALLED: path=#{path.inspect}, env=#{Rails.env}, relative_url_root=#{Rails.application.config.relative_url_root.inspect}"

    full_path = subpath_aware_url(path)
    Rails.logger.info "🔍 NAV_LINK RESULT: final full_path=#{full_path.inspect}"

    css_classes = [
      "group flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors duration-200",
      active ? "bg-blue-100 text-blue-700" : "text-gray-600 hover:bg-gray-100 hover:text-gray-900"
    ].join(" ")

    link_to(full_path, class: css_classes, "aria-current": (active ? "page" : nil)) do
      content_tag(:div, class: "flex items-center") do
        concat content_tag(:div, heroicon(icon, variant: :outline, size: 20),
                          class: "mr-3 flex-shrink-0 #{active ? 'text-blue-500' : 'text-gray-400 group-hover:text-gray-500'}")
        concat content_tag(:span, text, class: "sidebar-text truncate")
      end
    end
  end

  # Sidebar toggle button helper
  def sidebar_toggle_button
    content_tag(:button,
                onclick: "toggleSidebar()",
                class: "p-2 rounded-lg bg-gray-100 hover:bg-gray-200 transition-colors duration-200",
                title: t("sidebar.toggle_sidebar"),
                "aria-label": t("sidebar.toggle_sidebar")) do
      content_tag(:div, id: "sidebar-arrow", class: "transition-transform duration-300") do
        heroicon("chevron-left", variant: :outline, size: 16)
      end
    end
  end

  # Enhanced subpath-aware URL helper that works with both paths and URLs
  def subpath_aware_url(path_or_url, request = nil)
    # If it's already a full URL, return as-is
    return path_or_url if path_or_url.to_s.start_with?("http")

    # Ensure we have a path string
    path = path_or_url.to_s

    # In development with subpath configured, prepend subpath if not already present
    if Rails.env.development? && Rails.application.config.relative_url_root.present?
      subpath = Rails.application.config.relative_url_root
      unless path.start_with?(subpath)
        path = "#{subpath}#{path.start_with?('/') ? path : "/#{path}"}"
      end
    end

    path
  end

  # Helper to generate HeroIcons (assuming you have heroicons gem or similar)
  def heroicon(name, variant: :outline, size: 24, **options)
    # This is a placeholder - replace with your actual icon implementation
    # For now, return a simple SVG placeholder
    content_tag(:svg,
                class: "w-#{size/4} h-#{size/4}",
                fill: "none",
                stroke: "currentColor",
                "stroke-width": "2",
                viewBox: "0 0 24 24") do
      # Simple placeholder icon
      content_tag(:path, "", "stroke-linecap": "round", "stroke-linejoin": "round", d: "M4 6h16M4 12h16M4 18h16")
    end
  end
end
