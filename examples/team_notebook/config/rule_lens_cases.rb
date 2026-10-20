# frozen_string_literal: true

# This is ordinary Ruby, loaded after your application in the test environment.
# Prepare equivalent test inputs for each revision using your app's fixtures or
# factories. RuleLens does not load fixtures or reset your database for you.
# For multiple policies, replace policy/cases with:
# groups: [{ policy: ArticlePolicy, cases: article_cases },
#          { policy: ProfilePolicy, cases: profile_cases }]
# Case IDs must be unique across all groups (e.g. article.reader.update).
module RuleLensCapture
  def self.options
    DemoData.prepare_capture!
    {
      suite: "team-notebook-permissions",
      data_version: "team-notebook-v1",
      context: {},
      policy: ArticlePolicy,
      cases: NotebookCases.permissions
    }
  end
end
