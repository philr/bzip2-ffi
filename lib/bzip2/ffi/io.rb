module Bzip2
  module FFI
    # `IO` is a base class providing common functionality for the {Reader} and
    # {Writer} subclasses.
    #
    # `Bzip2::FFI::IO` holds a reference to an underlying `IO`-like stream
    # representing the bzip2-compressed data to be read from or written to.
    class IO
      class << self
        protected :new

        protected

        # If no block is provided, returns a new `IO`. If a block is provided,
        # a new `IO` is created and yielded to the block. After the block has
        # executed, the `IO` is closed and the result of the block is returned.
        #
        # If `io_or_proc` is a `Proc`, it is called to obtain an IO-like
        # instance to pass to `new`. Otherwise `io_or_proc` is passed directly
        # to `new`.
        #
        # @param io_or_proc [Object] An IO-like object or a `Proc` that returns
        #                            an IO-like object when called.
        # @param options [Hash] Options to pass to `new`.
        def open(io_or_proc, options = {})
          if io_or_proc.kind_of?(Proc)
            io = io_or_proc.call
            begin
              bz_io = new(io, options)
            rescue
              io.close if io.respond_to?(:close)
              raise
            end
          else
            bz_io = new(io_or_proc, options)
          end

          if block_given?
            begin            
              yield bz_io
            ensure
              bz_io.close unless bz_io.closed?
            end
          else
            bz_io
          end
        end

        # Opens and returns a bzip `File` using the specified mode. The system
        # is advised that the file will be accessed once sequentially.
        #
        # @param path [String] The path to open.
        # @param mode [String] The file open mode to use.
        # @return [File] An open `File` object for `path` opened using `mode`.
        def open_bzip_file(path, mode)
          io = File.open(path, mode)

          begin
            after_open_file(io)
          rescue
            io.close
            raise
          end

          io
        end

        private

        # Advises the system that an `IO` will be accessed once sequentially.
        #
        # @param io [IO] An `IO` instance to advise.
        def after_open_file(io)
          # JRuby 1.7.18 doesn't have a File#advise method (in any mode).
          if io.respond_to?(:advise)
            io.advise(:sequential)
            io.advise(:noreuse)
          end
        end
      end

      # Returns `true` if the underlying compressed `IO` instance will be closed
      # when {#close} is called, otherwise `false`.
      #
      # @return [Boolean] `true` if the underlying compressed IO instance will
      #                   be closed when {#close} is closed, otherwise `false`.
      # @raise [IOError] If the instance has been closed.
      def autoclose?
        check_closed
        @autoclose
      end

      # Sets whether the underlying compressed `IO` instance should be closed
      # when {#close} is called (`true`) or left open (`false`).
      #
      # @param autoclose [Boolean] `true` if the underlying compressed `IO`
      #                            instance should be closed when {#close} is
      #                            called, or `false` if it should be left open.
      # @raise [IOError] If the instance has been closed.
      def autoclose=(autoclose)
        check_closed
        @autoclose = !!autoclose
      end

      # Returns `true` to indicate that the `IO` is operating in binary mode
      # (as is always the case).
      #
      # @return [Boolean] `true`.
      # @raise [IOError] If the `IO` has been closed.
      def binmode?
        check_closed
        true
      end

      # Puts the `IO` into binary mode.
      #
      # Note that `Bzip2::FFI::IO` and subclasses always operate in binary mode,
      # so calling `binmode` has no effect.
      #
      # @return [IO] `self`.
      # @raise [IOError] If the `IO` has been closed.
      def binmode
        check_closed
        self
      end

      # Closes the `IO`.
      #
      # If {#autoclose?} is true and the underlying compressed `IO` responds to
      # `close`, it will also be closed.
      #
      # @return [NilClass] `nil`.
      # @raise [IOError] If the `IO` has already been closed.
      def close
        check_closed
        @io.close if autoclose? && @io.respond_to?(:close)
        @stream = nil
      end

      # Indicates whether the `IO` has been closed by calling {#close}.
      #
      # @return [Boolean] `true` if the `IO` has been closed, otherwise `false`.
      def closed?
        !@stream
      end

      # Returns the `Encoding` object that represents the encoding of data
      # prior to being compressed or after being decompressed.
      #
      # No character conversion is performed, so `external_encoding` always
      # returns `Encoding::ASCII_8BIT` (also known as `Encoding::BINARY`).
      #
      # @return [Encoding] `Encoding::ASCII_8BIT`.
      # @raise [IOError] If the `IO` has been closed.
      def external_encoding
        check_closed
        Encoding::ASCII_8BIT
      end

      # The internal encoding for character conversions.
      #
      # No character conversion is performed, so `internal_encoding` always
      # returns `Encoding::ASCII_8BIT` (also known as `Encoding::BINARY`).
      #
      # @return [Encoding] `Encoding::ASCII_8BIT`.
      # @raise [IOError] If the `IO` has been closed.
      def internal_encoding
        check_closed
        Encoding::ASCII_8BIT
      end
      
      protected

      # The underlying compressed `IO` instance.
      attr_reader :io

      # Initializes a new {Bzip2::FFI::IO} instance with an underlying
      # compressed `IO` instance and `options` `Hash`.
      #
      # `binmode` is called on `io` if `io` responds to `binmode`.
      #
      # A single `:autoclose` option is supported. Set `:autoclose` to true
      # to close the underlying compressed `IO` instance when {#close} is
      # called.
      #
      # @param io [IO] An `IO`-like object that represents the compressed data.
      # @param options [Hash] Optional parameters (:autoclose).
      # @raise [ArgumentError] If `io` is nil.
      def initialize(io, options = {})
        raise ArgumentError, 'io is required' unless io
        
        @io = io
        @io.binmode if @io.respond_to?(:binmode)        

        @autoclose = !!options[:autoclose]
        
        @stream = Libbz2::BzStream.new
      end

      # Returns the {Libbz2::BzStream} instance being used to interface with
      # libbz2.
      #
      # @return [Libbz2::BzStream] The {Libbz2::BzStream} instance being used
      #                            to interface with libbz2.
      # @raise [IOError] If the `IO` has been closed.
      def stream
        check_closed
        @stream
      end      

      # Raises an `IOError` if {#close} has been called to close the {IO}.
      #
      # @raise [IOError] If the `IO` has been closed.
      def check_closed
        raise IOError, 'closed stream' if closed?
      end

      # Checks a return code from a libbz2 function. If it is greater than or
      # equal to 0 (success), the return code is returned. If it is less than
      # zero (an error), the appropriate {Bzip2::Bzip2Error} sub-class is
      # raised.
      #
      # @param res [Integer] The result of a call to a libbz2 function.
      # @return [Integer] `res` if `res` is greater than or equal to 0.
      # @raise [Error::Bzip2Error] if `res` is less than 0.
      def check_error(res)
        return res if res >= 0

        error_class = case res
          when Libbz2::BZ_SEQUENCE_ERROR
            Error::SequenceError
          when Libbz2::BZ_PARAM_ERROR
            Error::ParamError
          when Libbz2::BZ_MEM_ERROR
            Error::MemoryError
          when Libbz2::BZ_DATA_ERROR
            Error::DataError
          when Libbz2::BZ_DATA_ERROR_MAGIC
            Error::MagicDataError
          when Libbz2::BZ_CONFIG_ERROR
            Error::ConfigError
          else
            raise Error::UnexpectedError.new(res)
        end

        raise error_class.new
      end      
    end
  end
end
