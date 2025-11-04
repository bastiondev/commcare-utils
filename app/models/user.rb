class User < ApplicationRecord
  passwordless_with :email
  
  validates :email, uniqueness: { case_sensitive: false }
  validates :email, presence: true

end
