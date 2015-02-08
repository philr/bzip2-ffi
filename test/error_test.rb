require 'test_helper'

class ErrorTest < Minitest::Test
  def test_initialize
    classes = [
      Bzip2::FFI::Error::SequenceError,
      Bzip2::FFI::Error::ParamError,
      Bzip2::FFI::Error::MemoryError,
      Bzip2::FFI::Error::ParamError,
      Bzip2::FFI::Error::DataError,
      Bzip2::FFI::Error::MagicDataError,
      Bzip2::FFI::Error::ConfigError,
      Bzip2::FFI::Error::UnexpectedEofError
    ]

    classes.each do |c|
      error = c.new
      refute_nil(error.message)
    end
  end

  def test_initialize_unexpected
    # -6, -7 and -8 are errors that are only raised by the libbz2 high-level
    # interface. Only the low-level interface is used by Bzip2::FFI.
    # -10 is not defined by libbz2.

    [-6, -7, -8, -10].each do |code|
      error = Bzip2::FFI::Error::UnexpectedError.new(code)
      assert_includes(error.message, code.to_s)
    end
  end
end
