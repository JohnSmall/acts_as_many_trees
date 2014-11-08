class CreateItemHierarchies < ActiveRecord::Migration
  def change
    create_table :item_hierarchies ,  :id => false do |t|
      t.references :ancestor
      t.references :descendant
      t.integer :generation
      t.string :hierarchy_scope
      t.decimal :position
    end
    add_index :item_hierarchies,[:descendant_id,:hierarchy_scope]
    add_index :item_hierarchies,[:ancestor_id,:descendant_id,:hierarchy_scope],unique:true,name: 'idx_unq_item_hierachy_ancestor_descendant_scope'
    add_index :item_hierarchies,[:ancestor_id,:hierarchy_scope,:position],name: 'idx_ancestor_scope_position'
  end
end
