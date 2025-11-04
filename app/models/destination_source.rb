class DestinationSource < ApplicationRecord
  include TableWritable

  belongs_to :destination

  validates :name, presence: true
  validates :url, presence: true
  validates :key_column, presence: true
  validates :table_name, presence: true
  validates :destination_id, presence: true

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
