class Item < ActiveRecord::Base
  acts_as_many_trees
  has_many :unscoped_ancestor_links,class_name: 'ItemHierarchy', foreign_key: 'descendant_id',dependent: :delete_all
  has_many :unscoped_descendant_links,class_name: 'ItemHierarchy',foreign_key: 'ancestor_id',dependent: :delete_all
end
