# In prod, each paper is its writer's. Locally there are no users, so it's optional.
class AddUserToPapers < ActiveRecord::Migration[8.1]
  def change
    add_reference :papers, :user, foreign_key: true
  end
end
