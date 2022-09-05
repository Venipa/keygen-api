# frozen_string_literal: true

module Groups
  class UserPolicy < ApplicationPolicy
    authorize :group

    scope_for :active_record_relation do |relation|
      case bearer
      in role: { name: 'admin' | 'developer' | 'read_only' | 'sales_agent' | 'support_agent' }
        relation.all
      in role: { name: 'product' } if relation.respond_to?(:for_product)
        relation.for_product(bearer.id)
      in role: { name: 'user' } if relation.respond_to?(:for_owner)
        relation.for_owner(bearer.id)
      else
        relation.none
      end
    end

    def index?
      verify_permissions!('group.users.read')

      case bearer
      in role: { name: 'admin' | 'developer' | 'sales_agent' | 'support_agent' | 'read_only' }
        allow!
      in role: { name: 'product' }
        allow!
      in role: { name: 'user' } if bearer.group_ids? && record.all? { _1.group_id? && _1.group_id.in?(bearer.group_ids) }
        allow!
      else
        deny!
      end
    end

    def show?
      verify_permissions!('group.users.read')

      case bearer
      in role: { name: 'admin' | 'developer' | 'sales_agent' | 'support_agent' | 'read_only' }
        allow!
      in role: { name: 'product' }
        allow!
      in role: { name: 'user' } if bearer.group_ids? && record.group_id? && record.group_id.in?(bearer.group_ids)
        allow!
      else
        deny!
      end
    end
  end
end