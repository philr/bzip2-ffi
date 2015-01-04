require 'simplecov'

SimpleCov.start do
  add_filter 'test'
  project_name 'Bzip2::FFI'
end

require 'bzip2/ffi'
require 'fileutils'
require 'minitest/autorun'
require 'open3'

module TestHelper
  BASE_DIR = File.expand_path(File.dirname(__FILE__))

  module Assertions
    def assert_files_identical(exp, act, msg = nil)
      msg = message(msg) { "Expected file #{act} to be identical to #{exp}" }
      assert(FileUtils.identical?(exp, act), msg)
    end

    def assert_bzip2_successful(*arguments)
      out, err, status = Open3.capture3(*(['bzip2'] + arguments))

      args_string = arguments.collect {|a| "'#{a}'" }.join(' ')
      assert(err == '', "`bzip2 #{args_string}` returned error: #{err}")
      assert(out == '', "`bzip2 #{args_string}` returned output: #{out}")
      assert(status.exitstatus == 0, "`bzip2 #{args_string}` exit status was non-zero")
    end

    def assert_bunzip2_successful(*arguments)
      assert_bzip2_successful(*(['--decompress'] + arguments))
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
