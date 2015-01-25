require 'rubygems'
require 'rubygems/package_task'
require 'rake/testtask'

BASE_DIR = File.expand_path(File.dirname(__FILE__))

task :default => :test

def spec
  @spec ||= eval(File.read('bzip2-ffi.gemspec'))
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
