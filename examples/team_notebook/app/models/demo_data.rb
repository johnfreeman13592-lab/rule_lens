module DemoData
  ACTORS = { "aoi" => "あおい", "haru" => "はる", "rin" => "りん", "sora" => "そら" }.freeze
  TEAMS = { "alpha" => "チームA", "beta" => "チームB" }.freeze
  MEMBERSHIPS = [%w[aoi alpha admin], %w[haru alpha editor], %w[haru beta member], %w[rin alpha member], %w[sora beta admin]].freeze

  def self.ensure!(offset: 0)
    ACTORS.each_with_index do |(slug, name), index|
      User.find_or_create_by!(slug: slug) { |user| user.id = offset + index + 1; user.name = name }
    end
    TEAMS.each_with_index do |(slug, name), index|
      Team.find_or_create_by!(slug: slug) { |team| team.id = offset + index + 1; team.name = name }
    end
    MEMBERSHIPS.each do |actor, group, role|
      Membership.find_or_create_by!(user: User.find_by!(slug: actor), team: Team.find_by!(slug: group)) { |membership| membership.role = role }
    end
    [%w[alpha aoi rin], %w[beta sora haru]].each_with_index do |(group, admin, member), team_index|
      [["public", admin, true], ["admin-draft", admin, false], ["member-draft", member, false]].each_with_index do |(slug, actor, published), index|
        team = Team.find_by!(slug: group)
        Article.find_or_create_by!(team: team, slug: slug) do |article|
          article.id = offset + team_index * 3 + index + 1
          article.author = User.find_by!(slug: actor)
          article.title = "#{team.name}の#{published ? '公開記事' : actor == admin ? '管理者の非公開記事' : 'メンバーの非公開記事'}"
          article.body = "#{article.author.name}が書いた検証用の記事です。"
          article.published = published
        end
      end
    end
  end

  def self.prepare_capture!
    raise "Capture fixtures require test" unless Rails.env.test?
    offset = Integer(ENV.fetch("RULE_LENS_FIXTURE_ID_OFFSET", "0"), 10)
    raise ArgumentError, "offset must be non-negative" if offset.negative?
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Migration.suppress_messages { load Rails.root.join("db/schema.rb") }
    ensure!(offset: offset)
  end
end
