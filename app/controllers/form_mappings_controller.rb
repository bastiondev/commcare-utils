class FormMappingsController < ApplicationController
  before_action :require_user!
  before_action :set_destination
  before_action :set_form_mapping, only: [:edit, :update, :destroy]

  def new
    @form_mapping = @destination.form_mappings.build
  end

  def create
    @form_mapping = @destination.form_mappings.build(form_mapping_params)
    if @form_mapping.save
      redirect_to destination_path(@destination), notice: 'Form mapping was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @form_mapping.update(form_mapping_params)
      redirect_to destination_path(@destination), notice: 'Form mapping was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @form_mapping.destroy
    redirect_to destination_path(@destination), notice: 'Form mapping was successfully deleted.'
  end

  private

  def set_destination
    @destination = Destination.find(params[:destination_id])
  end

  def set_form_mapping
    @form_mapping = @destination.form_mappings.find(params[:id])
  end

  def form_mapping_params
    params.require(:form_mapping).permit(:name, :form_names)
  end
end
