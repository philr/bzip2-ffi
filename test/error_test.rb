# encoding: UTF-8
# frozen_string_literal: true

require_relative 'test_helper'

class ErrorTest < Minitest::Test
  def test_initialize_base_class
    message = 'Dummy error message'
    error = Bzip2::FFI::Error::Bzip2Error.new(message)
    assert_same(message, error.message)
  end

  [
    Bzip2::FFI::Error::SequenceError,
    Bzip2::FFI::Error::ParamError,
    Bzip2::FFI::Error::MemoryError,
    Bzip2::FFI::Error::DataError,
    Bzip2::FFI::Error::MagicDataError,
    Bzip2::FFI::Error::ConfigError,
    Bzip2::FFI::Error::UnexpectedEofError
  ].each do |c|
    define_method("test_initialize_sub_classes_#{c.name.split('::').last.gsub(/([a-z])([A-Z])/, '\1_\2').downcase}") do
      error = c.new
      refute_nil(error.message)
    end
  end

  # -6, -7 and -8 are errors that are only raised by the libbz2 high-level
  # interface. Only the low-level interface is used by Bzip2::FFI. -10 is not
  # defined by libbz2.
  [-6, -7, -8, -10].each do |code|
    define_method("test_initialize_unexpected_#{code}") do
      error = Bzip2::FFI::Error::UnexpectedError.new(code)
      assert_includes(error.message, code.to_s)
    end
  end
end
