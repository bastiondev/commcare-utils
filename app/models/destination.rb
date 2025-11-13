class Destination < ApplicationRecord
  has_many :destination_sources, dependent: :destroy
  has_many :destination_tokens, dependent: :destroy

  encrypts :database_url
  encrypts :commcare_password

  validates :name, presence: true
  validates :project_name, presence: true
  validates :database_url, presence: true
  validates :commcare_username, presence: true
  validates :commcare_password, presence: true

  def create_token
    destination_tokens.create
  end


  def handle_forwarded_case case_id
    case_data = commcare_client.get_case(case_id)
    source = destination_sources.where('lower(trim(case_type)) = ?', case_data['properties']['case_type'].downcase.strip).first
    # Get owner data if present
    if case_data['properties'] && case_data['properties']['owner_id'].present?
      owner_location = commcare_client.get_location(case_data['properties']['owner_id'])
    end
    # Get user data if present
    if case_data['opened_by'].present?
      opened_by_user = commcare_client.get_user(case_data['opened_by'])
    end
    if case_data['closed_by'].present?
      closed_by_user = commcare_client.get_user(case_data['closed_by'])
    end
    if source
      source.sync_case case_data, owner_location, opened_by_user, closed_by_user
    else
      raise "Case type not found: #{case_data['case_type']} for case id: #{case_id}"
    end
  end

  def commcare_client
    @commcare_client ||= CommcareClient.new(commcare_username, commcare_password, project_name)
  end

  # Returns database_url with the password masked
  def database_url_for_display
    # Parse database_url into components and then only display the host, port, and path
    uri = URI.parse(database_url)
    "postgres://#{uri.host}:#{uri.port}#{uri.path}"
  end

end
