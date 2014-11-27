FactoryGirl.define do
  factory :item do
    sequence(:name) {|n| "name#{n}" }
  end

end

FactoryGirl.define do
  factory :sub_item do
    sequence(:name) {|n| "name#{n}" }
  end

end
    

