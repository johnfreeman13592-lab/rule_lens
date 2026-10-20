class Article < ApplicationRecord
  belongs_to :team
  belongs_to :author, class_name: "User"
  before_validation(on: :create) { self.slug ||= SecureRandom.uuid }
  validates :slug, presence: true, uniqueness: { scope: :team_id }
  validates :title, :body, presence: true
  validates :published, inclusion: { in: [true, false] }
  validate :author_belongs_to_team

  def record_key = "#{team.slug}/#{slug}"

  private

  def author_belongs_to_team
    unless team && author && Membership.exists?(team: team, user: author)
      errors.add(:author, "は所属チームのメンバーを指定してください")
    end
  end
end
