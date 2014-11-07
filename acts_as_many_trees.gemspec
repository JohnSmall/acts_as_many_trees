$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "acts_as_many_trees/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "acts_as_many_trees"
  s.version     = ActsAsManyTrees::VERSION
  s.authors     = ["TODO: Your name"]
  s.email       = ["TODO: Your email"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of ActsAsManyTrees."
  s.description = "TODO: Description of ActsAsManyTrees."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]

  s.add_dependency "rails", "~> 4.1.7"

  s.add_development_dependency "pg"
end
