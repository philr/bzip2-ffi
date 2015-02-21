module Bzip2
  module FFI
    # The Bzip2::FFI::Error namespace contains exception classes that are raised
    # if an error occurs whilst compressing or decompressing data.
    module Error
      # Base class for Bzip2::FFI exceptions.
      class Bzip2Error < IOError
      end

      # Raised if libbz2 functions were called out of sequence or with data
      # structures in incorrect states.
      class SequenceError < Bzip2Error
        # Initializes a new instance of SequenceError.
        #
        # @private
        def initialize #:nodoc:
          super('libbz2 functions called out of sequence or with data structures in incorrect states (this is likely to be caused by a bug in Bzip2::FFI)')
        end
      end

      # Raised if a parameter passed to libbz2 was out of range or incorrect.
      class ParamError < Bzip2Error
        # Initializes a new instance of ParamError.
        #
        # @private
        def initialize #:nodoc:
          super('A parameter passed to libbz2 is out of range or incorrect (this may indicate a bug in Bzip2::FFI)')
        end
      end

      # Raised if a failure occurred allocating memory to complete a request.
      class MemoryError < Bzip2Error
        # Initializes a new instance of MemoryError.
        #
        # @private
        def initialize #:nodoc:
          super('Could not allocate enough memory to perform this request')
        end
      end

      # Raised if a data integrity error is detected (a mismatch between
      # stored and computed CRCs or another anomaly in the compressed data).
      class DataError < Bzip2Error
        # Initializes a new instance of DataError.
        #
        # @param message [String] Exception message (overrides the default).
        # @private
        def initialize(message = nil) #:nodoc:
          super(message || 'Data integrity error detected (mismatch between stored and computed CRCs, or other anomaly in the compressed data)')
        end
      end

      # Raised if the compressed data does not start with the correct magic
      # bytes ('BZh').
      class MagicDataError < DataError
        # Initializes a new instance of MagicDataError.
        #
        # @private
        def initialize #:nodoc:
          super('Compressed data does not start with the correct magic bytes (\'BZh\')')
        end
      end

      # Raised if libbz2 detects that it has been improperly compiled.
      class ConfigError < Bzip2Error
        # Initializes a new instance of ConfigError.
        #
        # @private
        def initialize #:nodoc:
          super('libbz2 has been improperly compiled on your platform')
        end
      end

      # Raised if an end of file (EOF) condition was detected before the end
      # of the logical bzip2 stream.
      class UnexpectedEofError < Bzip2Error
        # UnexpectedEofError is raised directly by Reader. It does not map to
        # a libbz2 low-level interface error code.

        # Initializes a new instance of UnexpectedEofError.
        #
        # @private
        def initialize #:nodoc:
          super('EOF was detected before the end of the logical stream')
        end
      end

      # Raised if libbz2 reported an unexpected error code.
      class UnexpectedError < Bzip2Error
        # Initializes a new instance of UnexpectedError.
        #
        # @param error_code [Integer] The error_code reported by libbz2.
        # @private
        def initialize(error_code) #:nodoc:
          super("An unexpected error was detected (error code: #{error_code})")
        end
      end
    end
  end
end
