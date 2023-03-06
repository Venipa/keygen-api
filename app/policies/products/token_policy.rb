# frozen_string_literal: true

module Products
  class TokenPolicy < ApplicationPolicy
    authorize :product

    def index?
      verify_permissions!('token.read')
      verify_environment!(
        strict: false,
      )

      case bearer
      in role: { name: 'admin' | 'developer' | 'sales_agent' | 'support_agent' | 'read_only' }
        allow!
      in role: { name: 'product' } if product == bearer
        record.all? { _1 in bearer_type: ^(Product.name), bearer_id: ^(bearer.id) }
      else
        deny!
      end
    end

    def show?
      verify_permissions!('token.read')
      verify_environment!(
        strict: false,
      )

      case bearer
      in role: { name: 'admin' | 'developer' | 'sales_agent' | 'support_agent' | 'read_only' }
        allow!
      in role: { name: 'product' } if product == bearer && record.bearer == bearer
        allow!
      else
        deny!
      end
    end

    def create?
      verify_permissions!('product.tokens.generate')
      verify_environment!

      case bearer
      in role: { name: 'admin' | 'developer' }
        allow!
      else
        deny!
      end
    end
  end
end
