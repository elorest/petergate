require "bundler/gem_tasks"
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.pattern = 'dummy/test/**/*_test.rb'
  t.verbose = false
end

task default: :test
