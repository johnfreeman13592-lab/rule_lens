class CreateNotebook < ActiveRecord::Migration[8.1]
  def change
    create_table(:users) { |t| t.string :slug, null: false; t.string :name, null: false }
    add_index :users, :slug, unique: true
    create_table(:teams) { |t| t.string :slug, null: false; t.string :name, null: false }
    add_index :teams, :slug, unique: true
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.string :role, null: false
    end
    add_index :memberships, [:user_id, :team_id], unique: true
    create_table :articles do |t|
      t.references :team, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :slug, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.boolean :published, null: false, default: false
    end
    add_index :articles, [:team_id, :slug], unique: true
  end
end
