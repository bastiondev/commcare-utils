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

  def add_source
    @destination = Destination.find(params[:id])
    @destination.destination_sources.create(destination_source_params)
    redirect_to edit_destination_path(@destination)
  end

  def remove_source
    @destination = Destination.find(params[:id])
    @source = @destination.destination_sources.find(params[:source_id])
    @source.destroy
    redirect_to edit_destination_path(@destination)
  end

  private

  def set_destination
    @destination = Destination.find(params[:id])
  end

  def destination_params
    params.require(:destination).permit(:name, :database_url, :commcare_username, :commcare_password, :commcare_password_confirmation)
  end

  def destination_source_params
    params.require(:destination_source).permit(:name, :url, :key_column, :table_name)
  end
end
