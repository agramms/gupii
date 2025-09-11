module NavigationHelper
  def nav_link(path, icon_name, text, active: false, disabled: false, method: :get)
    css_classes = [
      "group flex items-center px-3 py-3 text-sm font-medium rounded-lg transition-all duration-300",
      active ? "bg-indigo-100 text-indigo-700 shadow-sm" : "text-gray-700",
      disabled ? "opacity-50 cursor-not-allowed" : "hover:bg-gray-50 hover:text-indigo-600 hover:shadow-sm",
      "focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-1"
    ].join(" ")

    link_to path, 
            class: css_classes, 
            method: method,
            "aria-current": (active ? "page" : nil),
            tabindex: (disabled ? -1 : 0),
            title: text,
            data: { tooltip: text } do
      content_tag(:div, class: "flex items-center w-full min-w-0") do
        heroicon_svg(icon_name, active: active) +
        content_tag(:span, text, class: "sidebar-text leading-tight break-words overflow-hidden", style: "hyphens: auto; word-break: break-word;")
      end
    end
  end

  def sidebar_toggle_button
    content_tag(:button, 
                class: "flex items-center justify-center w-8 h-8 rounded-lg bg-gray-100 hover:bg-gray-200 transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-indigo-500",
                onclick: "toggleSidebar()",
                title: "Toggle sidebar",
                "aria-label": "Toggle sidebar") do
      content_tag(:svg, class: "w-4 h-4 text-gray-600 transform transition-transform duration-300", 
                  id: "sidebar-arrow",
                  fill: "none", 
                  viewBox: "0 0 24 24", 
                  "stroke-width": "2", 
                  stroke: "currentColor") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M15 19l-7-7 7-7")
      end
    end
  end

  private

  def heroicon_svg(icon_name, active: false)
    icon_class = [
      "mr-3 h-5 w-5 flex-shrink-0 transition-colors duration-200",
      active ? "text-indigo-600" : "text-gray-400 group-hover:text-indigo-500"
    ].join(" ")

    case icon_name
    when 'home'
      content_tag(:svg, class: icon_class, fill: "none", viewBox: "0 0 24 24", "stroke-width": "1.5", stroke: "currentColor") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "m2.25 12 8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25")
      end
    when 'identification'
      content_tag(:svg, class: icon_class, fill: "none", viewBox: "0 0 24 24", "stroke-width": "1.5", stroke: "currentColor") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M15 9h3.75M15 12h3.75M15 15h3.75M4.5 19.5h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5zm6-10.125a1.875 1.875 0 11-3.75 0 1.875 1.875 0 013.75 0z")
      end
    when 'exclamation-triangle'
      content_tag(:svg, class: icon_class, fill: "none", viewBox: "0 0 24 24", "stroke-width": "1.5", stroke: "currentColor") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z")
      end
    when 'building-office-2'
      content_tag(:svg, class: icon_class, fill: "none", viewBox: "0 0 24 24", "stroke-width": "1.5", stroke: "currentColor") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M2.25 21h19.5m-18-18v18m2.25-18v18m13.5-18v18M6.75 6.75h.75m-.75 3h.75m-.75 3h.75m3-6h.75m-.75 3h.75m-.75 3h.75M6.75 21v-3.375c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21M3 3h12m-.75 4.5H21m-3.75 3.75h.008v.008h-.008v-.008Zm0 3h.008v.008h-.008v-.008Zm0 3h.008v.008h-.008v-.008Z")
      end
    when 'cog-6-tooth'
      content_tag(:svg, class: icon_class, fill: "none", viewBox: "0 0 24 24", "stroke-width": "1.5", stroke: "currentColor") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281Z")
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M15 12a3 3 0 11-6 0 3 3 0 016 0Z")
      end
    when 'arrow-right-on-rectangle'
      content_tag(:svg, class: icon_class, fill: "none", viewBox: "0 0 24 24", "stroke-width": "1.5", stroke: "currentColor") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15M12 9l-3 3m0 0l3 3m-3-3h12.75")
      end
    when 'scale'
      content_tag(:svg, class: icon_class, fill: "none", viewBox: "0 0 24 24", "stroke-width": "1.5", stroke: "currentColor") do
        content_tag(:path, nil, "stroke-linecap": "round", "stroke-linejoin": "round", d: "M12 3v17.25m0 0c-1.472 0-2.882.265-4.185.75M12 20.25c1.472 0 2.882.265 4.185.75M18.75 4.97A48.416 48.416 0 0012 4.5c-2.291 0-4.545.16-6.75.47m13.5 0c1.01.143 2.01.317 3 .52m-3-.52v15.627c0 .934.348 1.836.97 2.49M5.25 4.97c-1.01.143-2.01.317-3 .52m3-.52v15.627c0 .934-.348 1.836-.97 2.49m0 0A48.355 48.355 0 015.25 21m12.75-1.636A48.355 48.355 0 0118.75 21m-13.5 0c2.25.357 4.5.357 6.75 0m6.75 0c-2.25.357-4.5.357-6.75 0")
      end
    else
      # Default generic icon
      content_tag(:div, class: icon_class)
    end
  end
end