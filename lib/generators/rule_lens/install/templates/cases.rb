# frozen_string_literal: true

# This is ordinary Ruby, loaded after your application in the test environment.
# Prepare equivalent test inputs for each revision using your app's fixtures or
# factories. RuleLens does not load fixtures or reset your database for you.
module RuleLensCapture
  def self.options
    {
      suite: "app-permissions",
      data_version: "fixtures-v1",
      context: {},
      policy: nil, # Replace with your existing policy class, e.g. ArticlePolicy.
      cases: [
        # RuleLens::Pundit::Case.new(
        #   id: "reader.update", label: "Reader edits an article", query: :update?
        # ) { [build_reader, build_article] }
      ]
    }
  end
end
