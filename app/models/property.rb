class Property < ApplicationRecord
  has_many :units, dependent: :destroy
  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
