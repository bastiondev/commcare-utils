class DestinationToken < ApplicationRecord
  belongs_to :destination

  before_validation :generate_token, on: :create

  validates :token, presence: true, uniqueness: true

  # Authenticate a token and return the destination_token, or nil if invalid
  def self.authenticate(token_string)
    return nil if token_string.blank?

    destination_token = find_by(token: token_string)
    return nil unless destination_token

    destination_token.touch_last_accessed
    destination_token
  end

  # Update last_accessed_at only if it's been more than 1 minute to avoid excessive DB writes
  def touch_last_accessed
    if last_accessed_at.nil? || last_accessed_at < 1.minute.ago
      update_column(:last_accessed_at, Time.current)
    end
  end

  private

  def generate_token
    self.token = SecureRandom.uuid if token.blank?
  end
end
