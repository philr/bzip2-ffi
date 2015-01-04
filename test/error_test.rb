require 'test_helper'

class ErrorTest < Minitest::Test
  ERROR_CODES = [Bzip2::FFI::Libbz2::BZ_SEQUENCE_ERROR,
    Bzip2::FFI::Libbz2::BZ_PARAM_ERROR,
    Bzip2::FFI::Libbz2::BZ_PARAM_ERROR,
    Bzip2::FFI::Libbz2::BZ_MEM_ERROR,
    Bzip2::FFI::Libbz2::BZ_DATA_ERROR,
    Bzip2::FFI::Libbz2::BZ_DATA_ERROR_MAGIC,
    Bzip2::FFI::Libbz2::BZ_IO_ERROR,
    Bzip2::FFI::Libbz2::BZ_UNEXPECTED_EOF,
    Bzip2::FFI::Libbz2::BZ_OUTBUFF_FULL,
    Bzip2::FFI::Libbz2::BZ_CONFIG_ERROR]
  
  def test_valid_errors
    ERROR_CODES.each do |error_code|
      error = Bzip2::FFI::Error.new(error_code)
      assert_equal(error_code, error.error_code)
      refute_nil(error.message)
    end
  end

  def test_invalid_error
    [-10, 0, 1].each do |error_code|
      error = Bzip2::FFI::Error.new(error_code)
      assert_equal(error_code, error.error_code)
      refute_nil(error.message)
    end
  end  
end
