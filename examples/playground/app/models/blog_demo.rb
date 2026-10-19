# frozen_string_literal: true

require "rule_lens/pundit"

module BlogDemo
  User = Data.define(:id, :name, :role)
  Post = Data.define(:id, :title, :author_id, :published)

  # Ordinary Pundit policies; no RuleLens rule DSL is needed.
  class BeforePolicy
    attr_reader :user, :record

    def initialize(user, record)
      @user, @record = user, record
    end

    def show? = record.published || owner?
    def update? = owner?
    def destroy? = owner?

    private

    def owner? = !user.nil? && user.id == record.author_id
  end

  class CorrectPolicy < BeforePolicy
    def update? = super || user&.role == :editor
  end

  class BuggyPolicy < BeforePolicy
    # Deliberate demo bug: every signed-in user gets editing permission.
    def update? = !user.nil?
  end

  class ErrorPolicy < CorrectPolicy
    def update?
      raise "Deliberate demo evaluation failure" if user&.role == :reader

      super
    end
  end

  VERSIONS = {
    "correct" => ["予定どおり：編集者だけに編集を許可", CorrectPolicy].freeze,
    "buggy" => ["変更ミス：読者にも編集を許可", BuggyPolicy].freeze,
    "error" => ["評価エラー：読者の判定に失敗", ErrorPolicy].freeze
  }.freeze
  ACTORS = { "author" => "記事の本人", "editor" => "編集者", "reader" => "一般の読者", "visitor" => "未ログイン" }.freeze
  ACTIONS = { show?: "閲覧", update?: "編集", destroy?: "削除" }.freeze

  def self.cases
    ACTORS.flat_map do |actor, label|
      ACTIONS.map do |query, action|
        RuleLens::Pundit::Case.new(id: "#{actor}.#{query}", label: "#{label}が記事を#{action}", query: query) do
          user = case actor
                 when "author" then User.new(1, "あおい", :author)
                 when "editor" then User.new(2, "はる", :editor)
                 when "reader" then User.new(3, "りん", :reader)
                 end
          [user, Post.new(1, "はじめてのRails", 1, true)]
        end
      end
    end.freeze
  end

  def self.compare(version)
    RuleLens::Pundit.compare(cases: cases, before: BeforePolicy, after: VERSIONS.fetch(version).last)
  end
end
