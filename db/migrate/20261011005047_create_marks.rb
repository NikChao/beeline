class CreateMarks < ActiveRecord::Migration[8.1]
  def change
    create_table :marks do |t|
      t.references :draft, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :color, null: false
      t.json :points, null: false
      t.string :text

      t.timestamps
    end
  end
end
