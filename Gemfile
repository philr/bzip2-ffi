source "https://rubygems.org"

gemspec

group :development do
  gem 'rake', ['>= 12.2.1', '< 14']
  gem 'git', '~> 1.2', require: false
end

group :test do
  gem 'minitest', '~> 5.0'
  gem 'simplecov', '~> 0.9', require: false

  # coveralls is no longer maintained, but supports Ruby < 2.3.
  # coveralls_reborn is maintained, but requires Ruby >= 2.3.
  gem 'coveralls', git: 'https://github.com/philr/coveralls-ruby.git', require: false if RUBY_VERSION < '2.3'
  gem 'coveralls_reborn', '~> 0.13', require: false if RUBY_VERSION >= '2.3'


  # json is a dependency of simplecov. Version 2.3.0 is declared as compatible
  # with Ruby >= 1.9, but actually fails with a syntax error:
  # https://travis-ci.org/tzinfo/tzinfo/jobs/625092293#L605
  #
  # 2.5.1 is declared as compatible with Ruby >= 2.0, but actually fails to
  # compile with an undefined reference to `rb_funcallv` on Windows:
  # https://github.com/tzinfo/tzinfo/runs/1664656059#step:3:757
  #
  # 2.3.0 also fails to build the native extension with Rubinius:
  # https://travis-ci.org/tzinfo/tzinfo/jobs/625092305#L1310
  #
  # Limit to earlier compatible versions.
  if RUBY_VERSION < '2.0' || RUBY_ENGINE == 'rbx'
    gem 'json', '< 2.3.0'
  elsif RUBY_VERSION < '2.1' && RUBY_PLATFORM =~ /mingw/
    gem 'json', '< 2.5.0'
  end

  # ffi 1.9.15 is declared as compatible with Ruby >= 1.8.7, but doesn't compile
  # on Ruby 1.9.3 on Windows.
  #
  # The source version of ffi 1.15.5 is declared as compatible with Ruby >= 2.3.
  # The binary version of 1.15.5 is declared as compatible with Ruby >= 2.4, so
  # doesn't get used. The using the source version results in a segmentation
  # fault during libffi initialization.
  #
  # Binaries of 15.5.0 to 15.5.4 are declared as compatible with Ruby >= 2.3,
  # but don't get used with Bundler 2.3.23 and Ruby 2.3 on Windows.
  #
  # Limit to earlier compatible versions.
  if RUBY_VERSION < '2.0' && RUBY_PLATFORM =~ /mingw/
    gem 'ffi', '< 1.9.0'
  elsif RUBY_VERSION < '2.4' && RUBY_PLATFORM =~ /mingw/
    gem 'ffi', '< 1.15.0'
  end
end
