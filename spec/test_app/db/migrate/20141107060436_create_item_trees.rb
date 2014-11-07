class CreateItemTrees < ActiveRecord::Migration
  def change
    create_table :item_trees do |t|
      t.integer :ancestor_id
      t.integer :descendant_id
      t.string :tree_scope

      t.timestamps
    end
  end
end
