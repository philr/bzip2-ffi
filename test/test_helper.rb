# encoding: UTF-8
# frozen_string_literal: true

unless RUBY_ENGINE == 'jruby'
  require 'simplecov'
  require 'coveralls'

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ]

  SimpleCov.start do
    add_filter 'test'
    project_name 'Bzip2::FFI'
  end
end

require 'bzip2/ffi'
require 'fileutils'
require 'minitest/autorun'
require 'open3'

class Bzip2::FFI::IO
  class << self
    attr_accessor :test_after_open_file_raise_exception
    attr_accessor :test_after_open_file_last_io

    private

    alias_method :default_after_open_file, :after_open_file

    def after_open_file(io)
      @test_after_open_file_last_io = io
      default_after_open_file(io)
      raise 'test' if test_after_open_file_raise_exception
    end
  end
end

module TestHelper
  BASE_DIR = File.expand_path(File.dirname(__FILE__))

  module Assertions
    def assert_files_identical(exp, act, msg = nil)
      msg = message(msg) { "Expected file #{act} to be identical to #{exp}" }
      assert(FileUtils.identical?(exp, act), msg)
    end

    def assert_bzip2_successful(file)
      assert_bzip2_command_successful(path_separators_for_command(file))
    end

    def assert_bunzip2_successful(file)
      assert_bzip2_command_successful('--decompress', path_separators_for_command(file))
    end

    def assert_nothing_raised(msg = nil)
      begin
        yield
      rescue => e
        full_message = message(msg) { exception_details(e, 'Exception raised: ') }
        flunk(full_message)
      end
    end

    private

    if File::ALT_SEPARATOR
      def path_separators_for_command(path)
        path.gsub(File::SEPARATOR, File::ALT_SEPARATOR)
      end
    else
      def path_separators_for_command(path)
        path
      end
    end

    def assert_bzip2_command_successful(*arguments)
      command_with_arguments = ['bzip2'] + arguments
      begin
        out, err, status = Open3.capture3(*command_with_arguments)

        args_string = arguments.collect {|a| "'#{a}'" }.join(' ')
        assert(err == '', "`bzip2 #{args_string}` returned error: #{err}")
        assert(out == '', "`bzip2 #{args_string}` returned output: #{out}")

        # Ruby 1.9.3 on Windows intermittently returns a nil status. Assume that
        # the process completed successfully.
        if status
          assert(status.exitstatus == 0, "`bzip2 #{args_string}` exit status was non-zero")
        else
          puts "`#{command_with_arguments.join(' ')}`: command status was nil, assuming successful"
        end
      rescue Errno::EBADF => e
        # JRuby 1.7 intermittently reports a bad file descriptor when closing
        # one of the input or output streams. Assume that the process completed
        # successfully.
        puts "`#{command_with_arguments.join(' ')}`: Open3.capture3 raised Errno::EBADF, assuming successful"
        puts e.inspect
        puts e.backtrace.join("\n")
      end
    end
  end

  module Fixtures
    FIXTURES_DIR = File.join(BASE_DIR, 'fixtures')

    def fixture_path(fixture)
      File.join(FIXTURES_DIR, fixture)
    end
  end
end

class Minitest::Test
  include TestHelper::Assertions
  include TestHelper::Fixtures
end
