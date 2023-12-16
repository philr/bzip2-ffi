require 'rubygems'
require 'rubygems/package_task'
require 'rake/testtask'

BASE_DIR = File.expand_path(File.dirname(__FILE__))

task :default => :test

def spec
  return @spec if @spec
  path = File.join(BASE_DIR, 'bzip2-ffi.gemspec')
  @spec = TOPLEVEL_BINDING.eval(File.read(path), path)
end

# Attempt to find the private key and return a spec with added options for
# signing the gem if found.
def add_signing_key(spec)
  private_key_path = File.expand_path(File.join(BASE_DIR, '..', 'key', 'gem-private_key.pem'))

  if File.exist?(private_key_path)
    spec = spec.clone
    spec.signing_key = private_key_path
    spec.cert_chain = [File.join(BASE_DIR, 'gem-public_cert.pem')]
  else
    puts 'WARNING: Private key not found. Not signing gem file.'
  end

  spec
end

package_task = Gem::PackageTask.new(add_signing_key(spec)) do
end

# Ensure files are world-readable before packaging.
Rake::Task[package_task.package_dir_path].enhance do
  recurse_chmod(package_task.package_dir_path)
end

def recurse_chmod(dir)
  File.chmod(0755, dir)

  Dir.entries(dir).each do |entry|
    if entry != '.' && entry != '..'
      path = File.join(dir, entry)
      if File.directory?(path)
        recurse_chmod(path)
      else
        File.chmod(0644, path)
      end
    end
  end
end

task :tag do
  require 'git'
  g = Git.init(BASE_DIR)
  g.add_tag("v#{spec.version}", annotate: true, message: "Tagging v#{spec.version}")
end

Rake::TestTask.new do |t|
  t.libs = [File.join(BASE_DIR, 'test')]
  t.pattern = File.join(BASE_DIR, 'test', '**', '*_test.rb')
  t.warning = true
end

# Coveralls expects an sh compatible shell when running git commands with Kernel#`
# On Windows, the results end up wrapped in single quotes.
# Patch Coveralls::Configuration to remove the quotes.
if RUBY_PLATFORM =~ /mingw/
  module CoverallsFixConfigurationOnWindows
    def self.included(base)
      base.instance_eval do
        class << self
          alias_method :git_without_windows_fix, :git

          def git
            git_without_windows_fix.tap do |hash|
              hash[:head] = hash[:head].map {|k, v| [k, v =~ /\A'(.*)'\z/ ? $1 : v] }.to_h
            end
          end
        end
      end
    end
  end

  require 'coveralls'
  Coveralls::Configuration.send(:include, CoverallsFixConfigurationOnWindows)
end
