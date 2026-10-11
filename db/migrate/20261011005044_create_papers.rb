class CreatePapers < ActiveRecord::Migration[8.1]
  def change
    create_table :papers do |t|
      t.timestamps
    end
  end
end
