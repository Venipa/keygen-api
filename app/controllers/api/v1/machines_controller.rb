module Api::V1
  class MachinesController < Api::V1::BaseController
    has_scope :fingerprint
    has_scope :license
    has_scope :user
    has_scope :page, type: :hash

    before_action :scope_by_subdomain!
    before_action :authenticate_with_token!
    before_action :set_machine, only: [:show, :update, :destroy]

    # GET /machines
    def index
      @machines = policy_scope apply_scopes(current_account.machines).all
      authorize @machines

      render json: @machines
    end

    # GET /machines/1
    def show
      render_not_found and return unless @machine

      authorize @machine

      render json: @machine
    end

    # POST /machines
    def create
      license = current_account.licenses.find_by_hashid machine_params[:license]

      @machine = current_account.machines.new machine_params.merge(license: license)
      authorize @machine

      if @machine.save
        CreateWebhookEventService.new(
          event: "machine.created",
          account: current_account,
          resource: @machine
        ).execute

        render json: @machine, status: :created, location: v1_machine_url(@machine)
      else
        render_unprocessable_resource @machine
      end
    end

    # PATCH/PUT /machines/1
    def update
      render_not_found and return unless @machine

      authorize @machine

      if @machine.update(machine_params)
        CreateWebhookEventService.new(
          event: "machine.updated",
          account: current_account,
          resource: @machine
        ).execute

        render json: @machine
      else
        render_unprocessable_resource @machine
      end
    end

    # DELETE /machines/1
    def destroy
      render_not_found and return unless @machine

      authorize @machine

      CreateWebhookEventService.new(
        event: "machine.deleted",
        account: current_account,
        resource: @machine
      ).execute

      @machine.destroy
    end

    private

    attr_reader :parameters

    def set_machine
      @machine = current_account.machines.find_by_hashid params[:id]
    end

    def machine_params
      parameters[:machine]
    end

    def parameters
      @parameters ||= TypedParameters.build self do
        options strict: true

        on :create do
          param :machine, type: Hash do
            param :license, type: String
            param :fingerprint, type: String
            param :name, type: String, optional: true
            param :ip, type: String, optional: true
            param :hostname, type: String, optional: true
            param :platform, type: String, optional: true
            param :meta, type: Hash, optional: true
          end
        end

        on :update do
          param :machine, type: Hash do
            param :name, type: String, optional: true
            param :meta, type: Hash, optional: true
          end
        end
      end
    end
  end
end
