$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "acts_as_many_trees/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "acts_as_many_trees"
  s.version     = ActsAsManyTrees::VERSION
  s.authors     = ["John Small"]
  s.email       = ["john@aardvark.vidhya.tv"]
  s.homepage    = "http://aardvark.vidhya.tv"
  s.summary     = "Summary of ActsAsManyTrees."
  s.description = "Description of ActsAsManyTrees."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "rails", "~> 4.1.7"

  s.add_development_dependency "pg"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "factory_girl_rails"
end
