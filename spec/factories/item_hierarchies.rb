FactoryBot.define do
  factory :item_hierarchy do
    ancestor_id {create(:item).id}
    descendant_id {create(:item).id}
    hierarchy_scope { "MyString" }
    position { "9.99" }
  end

end
