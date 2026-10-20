class User < ApplicationRecord
  has_many :memberships, dependent: :restrict_with_exception
  has_many :teams, through: :memberships
  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
end
