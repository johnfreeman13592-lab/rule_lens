require "rule_lens/pundit/scope"

module NotebookCases
  ARTICLE_SLUGS = %w[public admin-draft member-draft].freeze
  QUERIES = [:show?, :update?, :destroy?].freeze

  def self.context(actor, group)
    AuthorizationContext.new(User.find_by!(slug: actor), Team.find_by!(slug: group))
  end

  def self.permissions
    DemoData::ACTORS.keys.flat_map do |actor|
      DemoData::TEAMS.keys.flat_map do |group|
        existing = DemoData::TEAMS.keys.flat_map do |record_group|
          ARTICLE_SLUGS.flat_map do |slug|
            QUERIES.map do |query|
              RuleLens::Pundit::Case.new(id: "#{actor}.#{group}.#{record_group}/#{slug}.#{query}", label: "#{DemoData::ACTORS[actor]} / #{DemoData::TEAMS[group]} / #{record_group}/#{slug} / #{query}", query: query) do
                [context(actor, group), Article.find_by!(team: Team.find_by!(slug: record_group), slug: slug)]
              end
            end
          end
        end
        existing + [RuleLens::Pundit::Case.new(id: "#{actor}.#{group}.create?", label: "#{DemoData::ACTORS[actor]}が#{DemoData::TEAMS[group]}に記事を作成", query: :create?) do
          input = context(actor, group)
          [input, Article.new(team: input.team, author: input.user)]
        end]
      end
    end
  end

  def self.scopes
    DemoData::ACTORS.keys.flat_map do |actor|
      DemoData::TEAMS.keys.map do |group|
        RuleLens::Pundit::ScopeCase.new(id: "#{actor}.#{group}.articles", label: "#{DemoData::ACTORS[actor]} / #{DemoData::TEAMS[group]}の記事一覧", key: ->(article) { article.record_key }) do
          [context(actor, group), Article.includes(:team).order(id: :desc)]
        end
      end
    end
  end
end
