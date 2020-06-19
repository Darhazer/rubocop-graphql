# frozen_string_literal: true

module RuboCop
  module Cop
    module GraphQL
      class ExtractType < Cop
        # This cop checks fields on common prefix groups
        #
        # # @example
        #   # good
        #
        #   class Types::UserType < Types::BaseObject
        #     field :registered_at, String, null: false
        #     field :contact, Types::ContactType, null: false
        #
        #     def contact
        #      self
        #     end
        #   end
        #
        #   class Types::ContactType < Types::BaseObject
        #     field :phone, String, null: false
        #     field :first_name, String, null: false
        #     field :last_name, String, null: false
        #   end
        #
        #   # bad
        #
        #   class Types::UserType < Types::BaseObject
        #     field :registered_at, String, null: false
        #     field :contact_phone, String, null: false
        #     field :contact_first_name, String, null: false
        #     field :contact_last_name, String, null: false
        #   end
        #
        include RuboCop::GraphQL::NodePattern

        def on_class(node)
          schema_member = RuboCop::GraphQL::SchemaMember.new(node)

          if (body = schema_member.body)
            check_fields_prefixes(body)
          end
        end

        private

        MSG = "Consider moving %<field_names>s to a new type and adding the `%<prefix>s` field instead"

        def check_fields_prefixes(body)
          sorted_prefixes = fractured(body).sort_by { |k, _| k.size }.reverse
          outdated = []

          sorted_prefixes.each do |prefix, fields|
            fields -= outdated
            next if fields.count < cop_config["MaxFields"]

            outdated += fields
            add_offense(
              fields.last.node,
              message: message(prefix, fields.map(&:name).join(", "))
            )
          end
        end

        def fractured(body)
          body.each_with_object({}) do |node, acc|
            next unless field?(node)

            field = RuboCop::GraphQL::Field.new(node)
            next unless field.underscore_name.include?("_")

            prefixes = field.underscore_name.split("_")[0..-2]

            prev_prefix = ""
            prefixes.each do |prefix|
              prefix = prev_prefix + prefix
              next if good_prefix?(prefix)

              acc[prefix] ||= []
              acc[prefix] << field
              prev_prefix = prefix + "_"
            end
          end
        end

        def message(prefix, field_names)
          format(MSG, field_names: field_names, prefix: prefix)
        end

        def good_prefix?(word)
          cop_config["Prefixes"].include?(word)
        end
      end
    end
  end
end
