class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :team
  validates :role, inclusion: { in: %w[admin editor member] }
  validates :user_id, uniqueness: { scope: :team_id }
end
