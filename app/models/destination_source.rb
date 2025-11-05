class DestinationSource < ApplicationRecord
  include TableWritable

  # Map meta properties to properties:
  META_PROPERTIES_MAP = {
    'case_id' => 'caseid',
    'owner_id' => 'owner_id',
    'date_opened' => 'date_opened',
    'last_modified' => 'last_modified',
    'server_last_modified' => 'server_last_modified',
    'indexed_on' => 'indexed_on',
    'closed' => 'closed',
    'date_closed' => 'date_closed',
  }

  belongs_to :destination

  before_create :set_default_sensitive_fields

  validates :name, presence: true
  validates :key_column, presence: true
  validates :table_name, presence: true
  validates :destination_id, presence: true

  # Sync a single case from CommCare, formatted in JSON from the API
  # Example
  # {"domain":"tt-patient-tracker","case_id":"2a4061f3-8d9a-4bb0-9f87-5b02133dbfc7","case_type":"Patient","case_name":"ggg","external_id":"","owner_id":"50c884ce835c44b4b727611689c462bb","date_opened":"2019-04-29T15:13:03.088000Z","last_modified":"2021-05-20T12:28:05.796000Z","server_last_modified":"2021-05-20T12:28:12.885737Z","indexed_on":"2021-05-20T12:28:21.019396Z","closed":true,"date_closed":"2021-05-20T12:28:05.796000Z","properties":{"age":"30","patient_district_id":"a8865b8249ee4c55b1d10245c008fe91","patient_district_name":"Beta 1","patient_id":"AA4V5","patient_id_manual_entry_not_found":"1","patient_phone_owner":"patient","patient_region_id":"da0b274a8d9c491784f71500c73536ad","patient_region_name":"Beta","patient_village_name":"GG","phone_contact":"patient","phone_number":"444","registration_notes":"","sex":"male","patient_close":"1","patient_close_date":"2021-05-20","patient_close_notes":"","patient_close_personnel":"Babel","patient_close_reason":"duplicate_record"},"indices":{"parent":{"case_id":"b2292c98-6acf-47b3-aff4-ada6a5340c82","case_type":"Surgery_Session","relationship":"child"}}}
  def sync_case case_data
    properties = case_data['properties']
    properties_to_upsert = properties.dup
    # Copy in meta properties needed
    META_PROPERTIES_MAP.each do |meta_property, property|
      properties_to_upsert[property] = case_data[meta_property]
    end
    # One-way hash sensitive fields
    (sensitive_fields || '').split(',').map(&:strip).each do |field|
      properties_to_upsert["#{field} *sensitive*"] = Digest::SHA256.hexdigest(properties[field])[0, 15]
    end
    ensure_table properties_to_upsert.keys
    upsert_row properties_to_upsert.keys, properties_to_upsert.values, DateTime.now
  end
  
  private

  def set_default_sensitive_fields
    self.sensitive_fields ||= ENV['DEFAULT_SENSITIVE_FIELDS']
  end

  def sync_source
    headers = nil
    start_time = DateTime.now
    num_rows = 0
    parse_source do |row|
      unless headers
        headers = sanitize_headers row
        ensure_table headers
      else
        upsert_row headers, row, start_time
        num_rows = num_rows + 1
      end
    end
    delete_rows_updated_before start_time
    return num_rows
  end

end
