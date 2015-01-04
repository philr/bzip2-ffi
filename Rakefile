require 'rake/testtask'

BASE_DIR = File.expand_path(File.dirname(__FILE__))

task :default => :test

Rake::TestTask.new do |t|
  t.libs = [File.join(BASE_DIR, 'test')]
  t.pattern = File.join(BASE_DIR, 'test', '**', '*_test.rb')
  t.warning = true
end
