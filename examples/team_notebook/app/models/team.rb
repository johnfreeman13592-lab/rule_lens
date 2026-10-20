class Team < ApplicationRecord
  has_many :memberships, dependent: :restrict_with_exception
  has_many :articles, dependent: :restrict_with_exception
  validates :slug, presence: true, uniqueness: true
  validates :name, presence: true
end
