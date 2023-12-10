FactoryBot.define do
  factory :item do
    sequence(:name) {|n| "name#{n}" }
  end

end

FactoryBot.define do
  factory :sub_item do
    sequence(:name) {|n| "name#{n}" }
  end

  factory :named_item do
    sequence(:name) {|n| "name#{n}" }
  end

end
