class DestinationToken < ApplicationRecord
  belongs_to :destination

  before_validation :generate_token, on: :create

  validates :token, presence: true, uniqueness: true

  private

  def generate_token
    self.token = SecureRandom.uuid if token.blank?
  end
end
