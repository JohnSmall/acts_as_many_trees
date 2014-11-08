FactoryGirl.define do
  factory :item do
    sequence(:name) {|n| "name#{n}" }
  end

end
