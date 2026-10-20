require "rule_lens/pundit"

module ReviewCases
  def self.groups
    profile_cases = %w[author editor reader].map do |actor|
      RuleLens::Pundit::Case.new(id: "profile.#{actor}.update", label: "#{actor} edits author's profile", query: :update?) do
        [ReviewUser.find_by!(fixture_key: actor), ReviewUser.find_by!(fixture_key: "author")]
      end
    end
    [{ policy: ArticlePolicy, cases: build }, { policy: ProfilePolicy, cases: profile_cases }]
  end

  def self.build
    { "author" => "本人", "editor" => "編集者", "reader" => "読者" }.flat_map do |actor, label|
      { show?: "閲覧", update?: "編集" }.map do |query, action|
        RuleLens::Pundit::Case.new(id: "#{actor}.#{query}", label: "#{label}が記事を#{action}", query: query) do
          [ReviewUser.find_by!(fixture_key: actor), ReviewArticle.find_by!(fixture_key: "article")]
        end
      end
    end
  end
end
