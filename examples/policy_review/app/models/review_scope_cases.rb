require "rule_lens/pundit/scope"

module ReviewScopeCases
  def self.build
    %w[author reader].map do |actor|
      RuleLens::Pundit::ScopeCase.new(id: "#{actor}.articles", label: "#{actor}の記事一覧", key: ->(record) { record.fixture_key }) do
        [ReviewUser.find_by!(fixture_key: actor), ReviewArticle.order(id: :desc)]
      end
    end
  end
end
