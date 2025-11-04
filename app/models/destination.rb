class Destination < ApplicationRecord
  has_many :destination_sources, dependent: :destroy

  encrypts :database_url
  encrypts :commcare_password

  validates :name, presence: true
  validates :database_url, presence: true
  validates :commcare_username, presence: true
  validates :commcare_password, presence: true
end
