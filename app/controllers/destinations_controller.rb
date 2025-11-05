class DestinationsController < ApplicationController
  before_action :require_user!
  before_action :set_destination, only: [:show, :edit, :update, :destroy]

  def index
    @destinations = Destination.all
  end

  def show
  end

  def new
    @destination = Destination.new
  end

  def create
    @destination = Destination.new(destination_params)
    if @destination.save
      redirect_to @destination, notice: 'Destination was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    params_to_update = destination_params
    params_to_update.delete(:commcare_password) if params_to_update[:commcare_password].blank?
    
    if @destination.update(params_to_update)
      redirect_to @destination, notice: 'Destination was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @destination.destroy
    redirect_to destinations_url, notice: 'Destination was successfully deleted.'
  end

  def create_token
    @destination = Destination.find(params[:id])
    @token = @destination.create_token  
    if @token.persisted?
      redirect_to destination_path(@destination), notice: 'Token was successfully created.'
    else
      Rails.logger.error("Token creation failed: #{@token.errors.full_messages.join(', ')}")
      redirect_to destination_path(@destination), alert: "Failed to create token: #{@token.errors.full_messages.join(', ')}"
    end
  end

  def delete_token
    @destination = Destination.find(params[:id])
    @token = @destination.destination_tokens.find(params[:token_id])
    @token.destroy
    redirect_to destination_path(@destination), notice: 'Token was successfully deleted.'
  end

  private

  def set_destination
    @destination = Destination.find(params[:id])
  end

  def destination_params
    params.require(:destination).permit(:name, :project_name, :database_url, :commcare_username, :commcare_password, :commcare_password_confirmation)
  end

end
