$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "acts_as_many_trees/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "acts_as_many_trees"
  s.version     = ActsAsManyTrees::VERSION
  s.authors     = ["John Small"]
  s.email       = ["jds340+rubygems@gmail.com"]
  s.homepage    = ""
  s.summary     = "ActiveRecord acts as tree, with many trees"
  s.description = "Uses the closure tree pattern with a scope field to maintain separate hierarchies"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "rails", ">= 7.0"

  s.add_development_dependency "pg",'~>1.1'
  s.add_development_dependency "rspec-rails",'~>6.1'
  s.add_development_dependency "factory_bot_rails",'~>6.4'
end
