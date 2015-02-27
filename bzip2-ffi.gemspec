require File.expand_path(File.join('..', 'lib', 'bzip2', 'ffi', 'version'), __FILE__)

Gem::Specification.new do |s|
  s.name = 'bzip2-ffi'
  s.version = Bzip2::FFI::VERSION
  s.summary = 'Reads and writes bzip2 compressed data using FFI bindings for libbz2.'
  s.description = <<-EOF
    Bzip2::FFI is a Ruby wrapper for libbz2 using FFI bindings.

    The Bzip2::FFI Reader and Writer classes support reading and writing bzip2
    compressed data as an IO-like stream.
  EOF
  s.author = 'Philip Ross'
  s.email = 'phil.ross@gmail.com'
  s.homepage = 'https://github.com/philr/bzip2-ffi'
  s.license = 'MIT'
  s.files = %w(CHANGES.md Gemfile LICENSE README.md Rakefile bzip2-ffi.gemspec .yardopts) +
            Dir['lib/**/*.rb'] +
            Dir['test/**/*.rb'] +
            Dir['test/fixtures/*']
  s.platform = Gem::Platform::RUBY
  s.require_path = 'lib'
  s.rdoc_options << '--title' << 'Bzip2::FFI' <<
                    '--main' << 'README.md' <<
                    '--markup' << 'markdown'
  s.extra_rdoc_files = ['CHANGES.md', 'LICENSE', 'README.md']
  s.required_ruby_version = '>= 1.9.3'
  s.add_runtime_dependency 'ffi', '~> 1.0'
  s.requirements << 'libbz2.(so|dll|dylib) available on the library search path'
end
