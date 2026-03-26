class FormMappingTablesController < ApplicationController
  before_action :require_user!
  before_action :set_destination
  before_action :set_form_mapping
  before_action :set_form_mapping_table, only: [:edit, :update, :destroy]

  def new
    @form_mapping_table = @form_mapping.form_mapping_tables.build
  end

  def create
    @form_mapping_table = @form_mapping.form_mapping_tables.build(form_mapping_table_params)
    if @form_mapping_table.save
      redirect_to destination_path(@destination), notice: 'Table mapping was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @form_mapping_table.update(form_mapping_table_params)
      redirect_to destination_path(@destination), notice: 'Table mapping was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @form_mapping_table.destroy
    redirect_to destination_path(@destination), notice: 'Table mapping was successfully deleted.'
  end

  private

  def set_destination
    @destination = Destination.find(params[:destination_id])
  end

  def set_form_mapping
    @form_mapping = @destination.form_mappings.find(params[:form_mapping_id])
  end

  def set_form_mapping_table
    @form_mapping_table = @form_mapping.form_mapping_tables.find(params[:id])
  end

  def form_mapping_table_params
    params.require(:form_mapping_table).permit(:table_name, :json_path, :sensitive_fields)
  end
end
