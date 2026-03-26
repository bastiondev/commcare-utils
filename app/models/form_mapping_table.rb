class FormMappingTable < ApplicationRecord
  include TableWritable

  belongs_to :form_mapping
  has_one :destination, through: :form_mapping

  before_create :set_default_sensitive_fields

  validates :table_name, presence: true
  validates :json_path, presence: true
  validates :form_mapping_id, presence: true

  def key_column
    root_path? ? 'form_instance_id' : 'form_row_id'
  end

  def root_path?
    json_path == '.'
  end

  private

  def set_default_sensitive_fields
    self.sensitive_fields ||= ENV['DEFAULT_SENSITIVE_FIELDS']
  end
end
