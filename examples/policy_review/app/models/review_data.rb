module ReviewData
  def self.prepare(offset: 0)
    raise ArgumentError, "offset must be a non-negative Integer" unless offset.is_a?(Integer) && offset >= 0

    # This example always starts a fresh, private in-memory database. It never
    # connects to an application's existing database or imports production data.
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.define do
      suppress_messages do
        create_table :review_users do |table|
          table.string :fixture_key, null: false
          table.string :role, null: false
        end
        add_index :review_users, :fixture_key, unique: true
        create_table :review_articles do |table|
          table.string :fixture_key, null: false
          table.references :author, null: false, foreign_key: { to_table: :review_users }
        end
        add_index :review_articles, :fixture_key, unique: true
      end
    end
    %w[author editor reader].each_with_index do |key, index|
      ReviewUser.create!(id: offset + index + 1, fixture_key: key, role: key)
    end
    ReviewArticle.create!(id: offset + 10, fixture_key: "article", author: ReviewUser.find_by!(fixture_key: "author"))
  end
end
