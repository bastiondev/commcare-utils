class DestinationSourcesController < ApplicationController
  before_action :require_user!
  before_action :set_destination
  before_action :set_destination_source, only: [:edit, :update, :destroy, :sync]

  def new
    @destination_source = @destination.destination_sources.build
  end

  def create
    @destination_source = @destination.destination_sources.build(destination_source_params)
    if @destination_source.save
      redirect_to destination_path(@destination), notice: 'Destination source was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @destination_source.update(destination_source_params)
      redirect_to destination_path(@destination), notice: 'Destination source was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @destination_source.destroy
    redirect_to destination_path(@destination), notice: 'Destination source was successfully deleted.'
  end

  def sync
    SyncSourceJob.perform_later(@destination_source.id)
    redirect_to destination_path(@destination), notice: 'Sync job has been enqueued for this destination source.'
  end

  private

  def set_destination
    @destination = Destination.find(params[:destination_id])
  end

  def set_destination_source
    @destination_source = @destination.destination_sources.find(params[:id])
  end

  def destination_source_params
    params.require(:destination_source).permit(:name, :case_type, :url, :key_column, :table_name, :sensitive_fields, :scheduled_sync)
  end
end
