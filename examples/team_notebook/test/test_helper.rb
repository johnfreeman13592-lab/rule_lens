ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "rails/test_help"
ActiveRecord::Migration.maintain_test_schema!

class ActiveSupport::TestCase
  setup { DemoData.ensure! }

  def actor(slug) = User.find_by!(slug: slug)
  def team(slug) = Team.find_by!(slug: slug)
  def article(group, slug) = Article.find_by!(team: team(group), slug: slug)
  def context(actor_slug, group) = AuthorizationContext.new(actor(actor_slug), team(group))
end

class ActionDispatch::IntegrationTest
  def switch_actor(slug)
    post demo_session_path, params: { actor_slug: slug }
    assert_response :see_other
  end
end
