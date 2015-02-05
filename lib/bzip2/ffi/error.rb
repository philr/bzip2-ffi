module Bzip2
  module FFI
    class Error < IOError
    end

    class SequenceError < Error
      def initialize
        super('libbz2 functions called out of sequence or with data structures in incorrect states (this is likely to be caused by a bug in Bzip2::FFI)')
      end
    end

    class ParamError < Error
      def initialize
        super('A parameter is out of range or incorrect (this may indicate a bug in Bzip2::FFI)')
      end
    end

    class MemoryError < Error
      def initialize
        super('Could not allocate enough memory to perform this request')
      end
    end

    class DataError < Error
      def initialize(message = nil)
        super(message || 'Data integrity error detected (mismatch between stored and computed CRCs, or other anomaly in the compressed data)')
      end
    end

    class MagicDataError < DataError
      def initialize
        super('Compressed data does not start with the correct magic bytes (\'BZh\')')
      end
    end

    class ConfigError < Error
      def initialize
        super('libbz2 has been improperly compiled on your platform')
      end
    end

    class UnexpectedEofError < Error
      # UnexpectedEofError is raised directly by Reader. It does not map to
      # a libbz2 low-level interface error code.
      def initialize
        super('EOF was detected before the end of the logical stream')
      end
    end

    class UnexpectedError < Error
      def initialize(error_code)
        super("An unexpected error was detected (error code: #{error_code})")
      end
    end
  end
end
