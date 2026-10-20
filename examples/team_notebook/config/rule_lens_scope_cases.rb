# frozen_string_literal: true

# Ordinary Ruby loaded after your application in the test environment.
# Prepare equivalent fixtures/factories in each process. The generated script
# does not prepare or reset your database. Check its test connection settings.
module RuleLensScopeCapture
  def self.options
    DemoData.prepare_capture!
    # Add cases like:
    # RuleLens::Pundit::ScopeCase.new(
    #   id: "reader.articles", label: "Reader articles",
    #   key: ->(article) { article.fixture_key }
    # ) { [build_reader, Article.all] }
    # Use stable, non-sensitive String keys, not physical database IDs.
    # If the meaning of the key or case changes, update the case version.
    {
      suite: "team-notebook-visibility",
      data_version: "team-notebook-v1",
      context: {},
      scope_class: ArticlePolicy::Scope,
      cases: NotebookCases.scopes
    }
  end
end
