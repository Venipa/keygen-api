# frozen_string_literal: true

module Api::V1
  class EventLogsController < Api::V1::BaseController
    has_scope(:date, type: :hash, using: [:start, :end], only: :index)
    has_scope(:whodunnit, type: :hash, using: [:type, :id]) { |_, s, (t, id)| s.search_whodunnit(t, id) }
    has_scope(:resource, type: :hash, using: [:type, :id]) { |_, s, (t, id)| s.search_resource(t, id) }
    has_scope(:request) { |c, s, v| s.search_request_id(v) }
    has_scope(:event) { |c, s, v| s.for_event_type(v) }

    before_action :scope_to_current_account!
    before_action :require_active_subscription!
    before_action :require_ent_subscription!
    before_action :authenticate_with_token!
    before_action :set_event_log, only: [:show]

    def index
      authorize EventLog

      json = Rails.cache.fetch(cache_key, expires_in: 1.minute, race_condition_ttl: 30.seconds) do
        event_logs = apply_pagination(policy_scope(apply_scopes(current_account.event_logs)).preload(:event_type))
        data = Keygen::JSONAPI::Renderer.new.render(event_logs)

        data.tap do |d|
          d[:links] = pagination_links(event_logs)
        end
      end

      render json: json
    end

    def show
      authorize @event_log

      render jsonapi: @event_log
    end

    private

    def set_event_log
      @event_log = current_account.event_logs.find params[:id]
    end

    def cache_key
      [:event_logs, current_account.id, Digest::SHA2.hexdigest(request.query_string), CACHE_KEY_VERSION].join ":"
    end
  end
end