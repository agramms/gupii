# frozen_string_literal: true

module ApplicationHelper
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
