require "test_helper"

class AuthorizationTest < ActiveSupport::TestCase
  test "baseline policy and scope agree for every actor team and record" do
    assert_equal 152, NotebookCases.permissions.size
    assert_equal 8, NotebookCases.scopes.size
    DemoData::ACTORS.each_key do |actor_slug|
      DemoData::TEAMS.each_key do |group|
        input = context(actor_slug, group)
        visible = ArticlePolicy::Scope.new(input, Article.all).resolve.to_a
        Article.all.each do |record|
          policy = ArticlePolicy.new(input, record)
          same = record.team_id == input.team.id && input.member?
          owner = record.author_id == input.user.id
          assert_equal same && (record.published? || input.admin? || owner), policy.show?
          assert_equal same && (input.admin? || owner), policy.update?
          assert_equal same && (input.admin? || owner), policy.destroy?
          assert_equal policy.show?, visible.include?(record)
        end
        assert_equal input.member?, ArticlePolicy.new(input, Article.new(team: input.team, author: input.user)).create?
      end
    end
  end

  test "one person's editor role does not apply to another team" do
    assert_equal "editor", context("haru", "alpha").membership.role
    assert_equal "member", context("haru", "beta").membership.role
    refute ArticlePolicy.new(context("haru", "beta"), article("beta", "admin-draft")).show?
    assert ArticlePolicy.new(context("haru", "beta"), article("beta", "member-draft")).update?
    assert_empty ArticlePolicy::Scope.new(context("rin", "beta"), Article.all).resolve
  end

  test "seeding again preserves edited articles and membership roles" do
    record = article("alpha", "public")
    record.update!(title: "残しておきたい編集内容", body: "変更した本文", published: false)
    role = actor("haru").memberships.find_by!(team: team("alpha"))
    role.update!(role: "member")
    before = [User.count, Team.count, Membership.count, Article.count]
    DemoData.ensure!
    assert_equal before, [User.count, Team.count, Membership.count, Article.count]
    assert_equal "残しておきたい編集内容", record.reload.title
    refute record.published?
    assert_equal "member", role.reload.role
  end

  test "authors must belong to the selected team and slugs are unique within a team" do
    invalid = Article.new(team: team("beta"), author: actor("rin"), title: "記事", body: "本文")
    refute invalid.valid?
    assert invalid.errors[:author].any?
    duplicate = Article.new(team: team("alpha"), author: actor("aoi"), slug: "public", title: "記事", body: "本文")
    refute duplicate.valid?
    assert duplicate.errors[:slug].any?
  end
end
