module Api::V1
  class PoliciesController < Api::V1::BaseController
    has_scope :product
    has_scope :page, type: :hash

    before_action :scope_by_subdomain!
    before_action :authenticate_with_token!
    before_action :set_policy, only: [:show, :update, :destroy]

    # GET /policies
    def index
      @policies = policy_scope apply_scopes(current_account.policies).all
      authorize @policies

      render json: @policies
    end

    # GET /policies/1
    def show
      render_not_found and return unless @policy

      authorize @policy

      render json: @policy
    end

    # POST /policies
    def create
      product = current_account.products.find_by_hashid policy_params[:product]

      @policy = current_account.policies.new policy_params.merge(product: product)
      authorize @policy

      if @policy.save
        CreateWebhookEventService.new(
          event: "policy.created",
          account: current_account,
          resource: @policy
        ).execute

        render json: @policy, status: :created, location: v1_policy_url(@policy)
      else
        render_unprocessable_resource @policy
      end
    end

    # PATCH/PUT /policies/1
    def update
      render_not_found and return unless @policy

      authorize @policy

      if @policy.update(policy_params)
        CreateWebhookEventService.new(
          event: "policy.updated",
          account: current_account,
          resource: @policy
        ).execute

        render json: @policy
      else
        render_unprocessable_resource @policy
      end
    end

    # DELETE /policies/1
    def destroy
      render_not_found and return unless @policy

      authorize @policy

      CreateWebhookEventService.new(
        event: "policy.deleted",
        account: current_account,
        resource: @policy
      ).execute

      @policy.destroy
    end

    private

    attr_reader :parameters

    def set_policy
      @policy = current_account.policies.find_by_hashid params[:id]
    end

    def policy_params
      parameters[:policy]
    end

    def parameters
      @parameters ||= TypedParameters.build self do
        options strict: true

        on :create do
          param :policy, type: Hash do
            param :product, type: String
            param :encrypted, type: Boolean, optional: true
            param :use_pool, type: Boolean, optional: true
            param :name, type: String, optional: true
            param :price, type: Integer, optional: true
            param :duration, type: Integer, optional: true
            param :strict, type: Boolean, optional: true
            param :recurring, type: Boolean, optional: true
            param :floating, type: Boolean, optional: true
            param :max_machines, type: Integer, optional: true
            param :meta, type: Hash, optional: true
          end
        end

        on :update do
          param :policy, type: Hash do
            param :name, type: String, optional: true
            param :price, type: Integer, optional: true
            param :duration, type: Integer, optional: true
            param :strict, type: Boolean, optional: true
            param :recurring, type: Boolean, optional: true
            param :floating, type: Boolean, optional: true
            param :max_machines, type: Integer, optional: true
            param :meta, type: Hash, optional: true
          end
        end
      end
    end
  end
end
