class Unit < ApplicationRecord
  belongs_to :property
  validates :number, presence: true, uniqueness: { scope: :property_id }
end
