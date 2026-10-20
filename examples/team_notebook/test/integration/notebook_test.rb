require "test_helper"

class NotebookTest < ActionDispatch::IntegrationTest
  test "root offers only the current actor's teams and actor switching works" do
    get root_path
    assert_response :success
    assert_select "h1", text: "あおいのノートブック"
    assert_select "a[href=?]", team_articles_path(team("alpha")), count: 1
    assert_select "a[href=?]", team_articles_path(team("beta")), count: 0
    switch_actor("haru")
    follow_redirect!
    assert_select "h1", text: "はるのノートブック"
    assert_select "section.card", count: 2
    post demo_session_path, params: { actor_slug: "unknown" }
    assert_response :not_found
  end

  test "index exposes only visible records and hides forbidden edit links" do
    switch_actor("haru")
    get team_articles_path(team("alpha"))
    assert_response :success
    assert_select "article[data-record-key]", count: 1
    assert_select "article[data-record-key=?]", "alpha/public"
    assert_select "a[href=?]", edit_team_article_path(team("alpha"), article("alpha", "public")), count: 0
    get team_articles_path(team("beta"))
    assert_select "article[data-record-key]", count: 2
    assert_select "article[data-record-key=?]", "beta/admin-draft", count: 0
    assert_select "a[href=?]", edit_team_article_path(team("beta"), article("beta", "member-draft")), count: 1
  end

  test "non-members and private records are 404 through direct URLs for all actions" do
    switch_actor("rin")
    foreign_team = team("beta")
    foreign = article("beta", "public")
    get team_articles_path(foreign_team)
    assert_response :not_found
    get new_team_article_path(foreign_team)
    assert_response :not_found
    get team_article_path(foreign_team, foreign)
    assert_response :not_found
    get edit_team_article_path(foreign_team, foreign)
    assert_response :not_found
    post team_articles_path(foreign_team), params: { article: { title: "不正", body: "本文" } }
    assert_response :not_found
    patch team_article_path(foreign_team, foreign), params: { article: { title: "不正" } }
    assert_response :not_found
    delete team_article_path(foreign_team, foreign)
    assert_response :not_found
    own_team = team("alpha")
    private_record = article("alpha", "admin-draft")
    get team_article_path(own_team, private_record)
    assert_response :not_found
    get edit_team_article_path(own_team, private_record)
    assert_response :not_found
    patch team_article_path(own_team, private_record), params: { article: { title: "不正" } }
    assert_response :not_found
    delete team_article_path(own_team, private_record)
    assert_response :not_found
    assert_equal "チームAの管理者の非公開記事", private_record.reload.title
  end

  test "a record from a different team cannot be addressed under an accessible team" do
    switch_actor("haru")
    foreign = article("beta", "public")
    get team_article_path(team("alpha"), foreign)
    assert_response :not_found
    patch team_article_path(team("alpha"), foreign), params: { article: { title: "不正" } }
    assert_response :not_found
    delete team_article_path(team("alpha"), foreign)
    assert_response :not_found
  end

  test "members can create edit and delete their own articles without assigning another team or author" do
    switch_actor("rin")
    selected = team("alpha")
    assert_difference("Article.count", 1) do
      post team_articles_path(selected), params: { article: { title: "自分の記事", body: "本文", published: "0", author_id: actor("sora").id, team_id: team("beta").id, slug: "forged" } }
    end
    assert_response :see_other
    created = Article.order(:id).last
    assert_equal actor("rin"), created.author
    assert_equal selected, created.team
    refute_equal "forged", created.slug
    follow_redirect!
    assert_select "h1", text: "自分の記事"
    get edit_team_article_path(selected, created)
    assert_response :success
    patch team_article_path(selected, created), params: { article: { title: "更新した記事", published: "1", author_id: actor("sora").id, team_id: team("beta").id } }
    assert_response :see_other
    assert_equal "更新した記事", created.reload.title
    assert created.published?
    assert_equal actor("rin"), created.author
    assert_equal selected, created.team
    assert_difference("Article.count", -1) { delete team_article_path(selected, created) }
    assert_response :see_other
  end

  test "admins can edit and delete member articles only inside their team" do
    target = article("alpha", "member-draft")
    get edit_team_article_path(team("alpha"), target)
    assert_response :success
    patch team_article_path(team("alpha"), target), params: { article: { title: "管理者が更新" } }
    assert_response :see_other
    assert_equal "管理者が更新", target.reload.title
    assert_difference("Article.count", -1) { delete team_article_path(team("alpha"), target) }
    assert_response :see_other
  end

  test "invalid content renders a Japanese form and user content is escaped" do
    post team_articles_path(team("alpha")), params: { article: { title: "", body: "" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /タイトルを入力してください/
    target = article("alpha", "public")
    target.update!(title: "<script>alert(1)</script>", body: "<img src=x onerror=alert(1)>")
    get team_article_path(team("alpha"), target)
    assert_response :success
    assert_select "script", count: 0
    assert_select "img", count: 0
  end
end
