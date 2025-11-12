module Api
  class DataForwardingController < ApplicationController
    
    before_action :authenticate_token!

    def index
      render json: { status: 'OK' }, status: :ok
    end

    def create
      DataForwardJob.perform_later(@destination_token.id, request.raw_post)
      render json: { status: 'received' }, status: :accepted
    end

    private

    def authenticate_token!
      token = extract_token_from_header
      @destination_token = DestinationToken.authenticate(token)

      unless @destination_token
        return render json: { error: 'Unauthorized' }, status: :unauthorized
      end

      @destination = @destination_token.destination
    end

    def extract_token_from_header
      auth_header = request.headers['Authorization']
      return nil unless auth_header

      # Handle both "Bearer token" and "token" formats
      if auth_header.start_with?('Bearer ')
        auth_header.sub(/^Bearer\s+/, '')
      else
        auth_header
      end
    end
  end
end
