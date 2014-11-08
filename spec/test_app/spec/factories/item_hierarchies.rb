FactoryGirl.define do
  factory :item_hierarchy do
    ancestor_id 1
descendant_id 1
tree_scope "MyString"
position "9.99"
  end

end
