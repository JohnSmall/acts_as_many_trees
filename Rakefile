begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rdoc/task'

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'ActsAsManyTrees'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
Bundler::GemHelper.install_tasks

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)

  if defined?(RSpec)
    desc 'Run factory specs.'
    RSpec::Core::RakeTask.new(:factory_specs) do |t|
      t.pattern = './spec/factories_spec.rb'
    end
  end

  # task spec: :factory_specs
  task :default => :spec
  #http://erniemiller.org/
  desc 'run the console'
  task :console do
    require 'irb'
    require 'irb/completion'
    require 'lib/acts_as_many_trees' 
    ARGV.clear
    IRB.start
  end
rescue LoadError
  # no rspec available
end


