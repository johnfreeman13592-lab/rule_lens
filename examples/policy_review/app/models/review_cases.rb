require "rule_lens/pundit"

module ReviewCases
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
