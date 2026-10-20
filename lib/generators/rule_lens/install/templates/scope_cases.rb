# frozen_string_literal: true

# Ordinary Ruby loaded after your application in the test environment.
# Prepare equivalent fixtures/factories in each process. The generated script
# does not prepare or reset your database. Check its test connection settings.
module RuleLensScopeCapture
  def self.options
    # Add cases like:
    # RuleLens::Pundit::ScopeCase.new(
    #   id: "reader.articles", label: "Reader articles",
    #   key: ->(article) { article.fixture_key }
    # ) { [build_reader, Article.all] }
    # Use stable, non-sensitive String keys, not physical database IDs.
    # If the meaning of the key or case changes, update the case version.
    {
      suite: "app-visibility",
      data_version: "fixtures-v1",
      context: {},
      scope_class: nil, # Replace with your class, e.g. ArticlePolicy::Scope.
      cases: []
    }
  end
end
