# frozen_string_literal: true

require_relative 'rule'

module TypedParameters
  class Validator < Rule
    def call(params)
      raise InvalidParameterError, "is missing" if
        params.nil? && schema.required? && !schema.allow_nil?

      depth_first_map(params) do |param|
        type   = Types.for(param.value)
        schema = param.schema
        parent = param.parent

        # Handle nils
        if Types.nil?(type)
          raise InvalidParameterError, "cannot be nil" unless
            schema.required? && schema.allow_nil?

          next
        end

        # Assert type
        raise InvalidParameterError, "type mismatch (received unknown expected #{schema.type.name})" if
          type.nil?

        raise InvalidParameterError, "type mismatch (received #{type.name} expected #{schema.type.name})" if
          schema.type != type

        # Assert scalar values for params without children
        if schema.children.nil?
          case
          when Types.hash?(schema.type)
            param.value.each do |key, value|
              raise InvalidParameterError, 'unpermitted type (expected hash of scalar types)' unless
                Types.scalar?(value) || schema.allow_non_scalars?
            end
          when Types.array?(schema.type)
            param.value.each_with_index do |value, index|
              raise InvalidParameterError, 'unpermitted type (expected array of scalar types)' unless
                Types.scalar?(value) || schema.allow_non_scalars?
            end
          end
        end
      end
    end
  end
end