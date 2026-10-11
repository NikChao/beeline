class CreatePublications < ActiveRecord::Migration[8.1]
  def change
    create_table :publications do |t|
      t.references :paper, null: false, foreign_key: true, index: { unique: true }
      t.references :draft, null: false, foreign_key: true

      t.timestamps
    end
  end
end
