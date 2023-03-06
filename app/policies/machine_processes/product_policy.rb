# frozen_string_literal: true

module MachineProcesses
  class ProductPolicy < ApplicationPolicy
    authorize :machine_process

    def show?
      verify_permissions!('product.read')
      verify_environment!(
        strict: false,
      )

      case bearer
      in role: { name: 'admin' | 'developer' | 'sales_agent' | 'support_agent' | 'read_only' }
        allow!
      in role: { name: 'product' } if machine_process.product == bearer
        allow!
      in role: { name: 'user' } if machine_process.user == bearer
        allow!
      in role: { name: 'license' } if machine_process.license == bearer
        allow!
      else
        deny!
      end
    end
  end
end
