class FormMapping < ApplicationRecord
  belongs_to :destination
  has_many :form_mapping_tables, dependent: :destroy

  validates :name, presence: true
  validates :form_names, presence: true
  validates :destination_id, presence: true

  def form_names_array
    (form_names || '').split(',').map(&:strip).reject(&:blank?)
  end

  def matches_form_name?(form_name)
    form_names_array.any? { |fn| fn.casecmp(form_name.strip) == 0 }
  end
end
