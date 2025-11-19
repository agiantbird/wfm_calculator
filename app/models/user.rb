class User < ApplicationRecord
  # Associations
  has_many :reports, dependent: :destroy
  # Validations
  validates :name, presence: true
end
