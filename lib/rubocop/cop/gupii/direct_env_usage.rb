# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module Gupii
      # Prevents direct usage of ENV in favor of AppConfig
      #
      # @example
      #   # bad
      #   ENV['DATABASE_URL']
      #   ENV.fetch('REDIS_URL', 'default')
      #   ENV.dig('OAUTH', 'CLIENT_ID')
      #
      #   # good
      #   AppConfig.get('DATABASE_URL')
      #   AppConfig.get('REDIS_URL', 'default')
      #   AppConfig.oauth_client_id
      #
      class DirectEnvUsage < Base
        extend AutoCorrector

        MSG = "Use AppConfig instead of direct ENV access. " \
              "Replace `%<current>s` with `AppConfig.get('%<key>s'%<default>s)`"

        RESTRICT_ON_SEND = %i[[] fetch dig].freeze

        def_node_matcher :env_access?, <<~PATTERN
          (send (const {nil? cbase} :ENV) {:[] :fetch :dig} ...)
        PATTERN

        def_node_matcher :env_bracket_access?, <<~PATTERN
          (send (const {nil? cbase} :ENV) :[] str)
        PATTERN

        def_node_matcher :env_fetch_access?, <<~PATTERN
          (send (const {nil? cbase} :ENV) :fetch str ...)
        PATTERN

        def_node_matcher :env_dig_access?, <<~PATTERN
          (send (const {nil? cbase} :ENV) :dig str ...)
        PATTERN

        def on_send(node)
          return unless env_access?(node)

          # Allow usage in specific files
          return if allowed_file?

          register_offense(node)
        end

        private

        def register_offense(node)
          key, default_value = extract_key_and_default(node)
          return unless key

          key_value = key.respond_to?(:value) ? key.value : key
          default_part = default_value ? ", #{default_value.source}" : ""

          message = format(
            MSG,
            current: node.source,
            key:     key_value,
            default: default_part,
          )

          add_offense(node, message: message) do |corrector|
            replacement = build_replacement(key, default_value)
            corrector.replace(node, replacement)
          end
        end

        def extract_key_and_default(node)
          case node.method_name
          when :[]
            if env_bracket_access?(node)
              key = node.arguments[0]
              [ key, nil ]
            end
          when :fetch
            if env_fetch_access?(node)
              key = node.arguments[0]
              default_value = node.arguments[1] if node.arguments.length > 1
              [ key, default_value ]
            end
          when :dig
            if env_dig_access?(node)
              # For dig, we only take the first key
              key = node.arguments[0]
              [ key, nil ]
            end
          end
        end

        def build_replacement(key, default_value)
          key_source = key.respond_to?(:source) ? key.source : "\"#{key}\""
          if default_value
            "AppConfig.get(#{key_source}, #{default_value.source})"
          else
            "AppConfig.get(#{key_source})"
          end
        end

        def allowed_file?
          file_path = processed_source.file_path
          return true if file_path.include?("app/lib/app_config.rb")
          return true if file_path.include?("spec/")
          return true if file_path.include?("test/")
          return true if file_path.include?("config/database.yml")
          return true if file_path.end_with?(".yml", ".yaml")

          false
        end
      end
    end
  end
end
