module Bzip2
  module FFI
    class Error < IOError
      attr_reader :error_code

      ERROR_MESSAGES = {
        Libbz2::BZ_SEQUENCE_ERROR =>
          'libbz2 functions called out of sequence or with data structures in incorrect states (this is likely to be caused by a bug in bzip2-ffi)',
        Libbz2::BZ_PARAM_ERROR =>
          'A parameter is out of range or incorrect',
        Libbz2::BZ_MEM_ERROR =>
          'Could not allocate enough memory to perform this request',
        Libbz2::BZ_DATA_ERROR =>
          'Data integrity error detected (mismatch between stored and computed CRCs, or other anomaly in the compressed data)',
        Libbz2::BZ_DATA_ERROR_MAGIC => 
          'Compressed data does not start with the correct magic bytes (\'BZh\')',
        Libbz2::BZ_IO_ERROR =>
          'An error occurred reading or writing the compressed file',
        Libbz2::BZ_UNEXPECTED_EOF =>
          'EOF was detected before the end of the logical stream',
        Libbz2::BZ_OUTBUFF_FULL =>
          'The supplied output buffer is not large enough',
        Libbz2::BZ_CONFIG_ERROR =>
          'libbz2 has been improperly compined on your platform',
      }
            
      def initialize(error_code)
        @error_code = error_code
        super(ERROR_MESSAGES[error_code] || "Error #{error_code} (unknown error)")
      end
    end
  end
end
