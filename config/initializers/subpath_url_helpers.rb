# Subpath-aware URL generation for development environment
# This ensures all Rails path helpers generate URLs with the correct subpath prefix

if Rails.env.development? && Rails.application.config.relative_url_root.present?
  # Store the original URL generation method
  module ActionDispatch
    module Routing
      class RouteSet
        # Override the url_for method to include subpath
        alias_method :original_url_for, :url_for

        def url_for(options = nil, route_name = nil, url_strategy = nil, method_name = nil, reserved = {})
          url = original_url_for(options, route_name, url_strategy, method_name, reserved)

          # Apply subpath only to relative URLs that don't already have it
          if url && !url.start_with?("http") && !url.start_with?(Rails.application.config.relative_url_root)
            url = "#{Rails.application.config.relative_url_root}#{url}"
          end

          url
        end
      end
    end
  end

  # Also patch ActionView to ensure view URL helpers work correctly
  module ActionView
    module Helpers
      module UrlHelper
        # Override link_to to use our subpath-aware URL generation
        alias_method :original_link_to, :link_to

        def link_to(name = nil, options = nil, html_options = nil, &block)
          # If options is a string path, ensure it has subpath
          if options.is_a?(String) && options.start_with?("/") && !options.start_with?(Rails.application.config.relative_url_root)
            options = "#{Rails.application.config.relative_url_root}#{options}"
          end

          original_link_to(name, options, html_options, &block)
        end
      end
    end
  end
end
