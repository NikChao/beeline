class CreateDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :drafts do |t|
      t.references :paper, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :title, null: false
      t.string :author

      t.timestamps
    end

    add_index :drafts, %i[ paper_id number ], unique: true
  end
end
