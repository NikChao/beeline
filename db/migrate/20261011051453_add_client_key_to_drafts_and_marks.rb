# A key the client generates for each queued save, so replaying the same save
# after a lost response finds the first one instead of making a copy.
class AddClientKeyToDraftsAndMarks < ActiveRecord::Migration[8.1]
  def change
    add_column :drafts, :client_key, :string
    add_index :drafts, :client_key, unique: true
    add_column :marks, :client_key, :string
    add_index :marks, :client_key, unique: true
  end
end
