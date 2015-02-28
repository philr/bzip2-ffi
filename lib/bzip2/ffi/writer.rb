require 'pathname'

module Bzip2
  module FFI
    # `Writer` compresses and writes a bzip2 compressed stream or file. The
    # public instance methods of `Writer` are intended to be equivalent to those
    # of a standard `IO` object.
    #
    # Data can be written as a stream using {open} and {#write}. For example,
    # the following compresses lines read from standard input:
    #
    #     Bzip2::FFI::Writer.open(io_or_path) do |writer|
    #       ARGF.each_line do |line|
    #         writer.write(line)
    #       end
    #     end
    #
    # Alternatively, without passing a block to `open`:
    #
    #     writer = Bzip2::FFI::Writer.open(io_or_path)
    #     begin
    #       ARGF.each_line do |line|
    #         writer.write(line)
    #       end
    #     ensure
    #       writer.close
    #     end
    #
    # An entire bzip2 structure can be written in a single step using {write}:
    #
    #     Bzip2::FFI::Writer.write(io_or_path, 'Hello, World!')
    #
    # The {open} and {write} methods accept either an `IO`-like object or a file
    # path. `IO`-like objects must have a `write` method. Paths can be given as
    # either a `String` or `Pathname`.
    #
    # No character conversion is performed when writing and compressing. The
    # {write} and {#write} methods compress the raw bytes from the given
    # `String` (using the encoding of the `String`).
    class Writer < IO
      # Size of the buffer passed to libbz2 for it to write compressed data to.
      #
      # @private
      OUT_BUFFER_SIZE = 4096 #:nodoc:

      class << self
        # Use send to keep this hidden from YARD (visibility tag does not work).
        send(:public, :new)

        # Opens a {Writer} to compress and write bzip2 compressed data to
        # either an `IO`-like object or a file. `IO`-like objects must have a
        # `write` method. Files can be specified using either a `String`
        # containing the file path or a `Pathname`.
        #
        # If no block is given, the opened `Writer` instance is returned. After
        # writing data, the instance must be closed using the {#close} method in
        # order to complete the compression process.
        #
        # If a block is given, it will be passed the opened `Writer` instance
        # as an argument. After the block terminates, the `Writer` instance will
        # automatically be closed. `open` will then return the result of the
        # block.
        #
        # The following options can be specified using the `options` `Hash`:
        #
        # * `:autoclose` - When passing an `IO`-like object, set to `true` to
        #                  close the `IO` when the `Writer` instance is closed.
        # * `:block_size` - Specifies the block size used for compression. It
        #                   should be set to an integer between 1 and 9
        #                   inclusive. The actual block size used is 100 kB
        #                   times the chosen figure. 9 gives the best
        #                   compression, but requires most memory. 1 gives the
        #                   worst compression, but uses least memory. If not
        #                   specified, `:block_size` defaults to 9.
        # * `:work_factor` - Controls how the compression algorithm behaves
        #                    when presented with the worst case, highly
        #                    repetitive, input data. If compression runs into
        #                    difficulties caused by repetitive data, the
        #                    library switches from the standard sorting
        #                    algorithm to a fallback algorithm. The fallback is
        #                    slower than the standard algorithm by approximately
        #                    a factor of three, but always behaves reasonably,
        #                    no matter how bad the input. Lower values of
        #                    `:work_factor` reduce the amount of effort the
        #                    standard algorithm will expend before resorting to
        #                    the fallback. Allowable values range from 0 to 250
        #                    inclusive. 0 is a special case, equivalent to using
        #                    the default libbz2 work factor value (30 as of
        #                    bzip2 v1.0.6). If not specified, `:work_factor`
        #                    defaults to 0.
        #
        # If an `IO`-like object that has a `binmode` method is passed to
        # `open`, `binmode` will be called on `io_or_path` before yielding to
        # the block or returning.
        #
        # If a path to a file that already exists is passed to `open`, the file
        # will be truncated before writing.
        #
        # @param io_or_path [Object] Either an `IO`-like object with a `write`
        #                            method or a file path as a `String` or
        #                            `Pathname`.
        # @param options [Hash] Optional parameters (`:autoclose`, `:block_size`
        #                       and `:small`).
        # @return [Object] The opened `Writer` instance if no block is given, or
        #                  the result of the block if a block is given.
        # @raise [ArgumentError] If `io_or_path` is _not_ a `String`, `Pathname`
        #                        or an `IO`-like object with a `write` method.
        # @raise [Errno::ENOENT] If the parent directory of the specified file
        #                        does not exist.
        # @raise [Error::Bzip2Error] If an error occurs when initializing
        #                            libbz2.
        def open(io_or_path, options = {})
          if io_or_path.kind_of?(String) || io_or_path.kind_of?(Pathname)
            options = options.merge(autoclose: true)
            proc = -> { open_bzip_file(io_or_path.to_s, 'wb') }
            super(proc, options)
          elsif !io_or_path.kind_of?(Proc)
            super
          else
            raise ArgumentError, 'io_or_path must be an IO-like object or a path'
          end
        end

        # Compresses data from a `String` and writes an entire bzip2 compressed
        # structure to either an `IO`-like object or a file. `IO`-like objects
        # must have a `write` method. Files can be specified using either a
        # `String` containing the file path or a `Pathname`.
        #
        # The following options can be specified using the `options` `Hash`:
        #
        # * `:autoclose` - When passing an `IO`-like object, set to `true` to
        #                  close the `IO` when the `Writer` instance is closed.
        # * `:block_size` - Specifies the block size used for compression. It
        #                   should be set to an integer between 1 and 9
        #                   inclusive. The actual block size used is 100 kB
        #                   times the chosen figure. 9 gives the best
        #                   compression, but requires most memory. 1 gives the
        #                   worst compression, but uses least memory. If not
        #                   specified, `:block_size` defaults to 9.
        # * `:work_factor` - Controls how the compression algorithm behaves
        #                    when presented with the worst case, highly
        #                    repetitive, input data. If compression runs into
        #                    difficulties caused by repetitive data, the
        #                    library switches from the standard sorting
        #                    algorithm to a fallback algorithm. The fallback is
        #                    slower than the standard algorithm by approximately
        #                    a factor of three, but always behaves reasonably,
        #                    no matter how bad the input. Lower values of
        #                    `:work_factor` reduce the amount of effort the
        #                    standard algorithm will expend before resorting to
        #                    the fallback. Allowable values range from 0 to 250
        #                    inclusive. 0 is a special case, equivalent to using
        #                    the default libbz2 work factor value (30 as of
        #                    bzip2 v1.0.6). If not specified, `:work_factor`
        #                    defaults to 0.
        #
        # No character conversion is performed. The raw bytes from `string` are
        # compressed (using the encoding of `string`).
        #
        # If an `IO`-like object that has a `binmode` method is passed to
        # `write`, `binmode` will be called on `io_or_path` before any
        # compressed data is written.
        #
        # The number of uncompressed bytes written is returned.
        #
        # @param io_or_path [Object] Either an `IO`-like object with a `write`
        #                            method or a file path as a `String` or
        #                            `Pathname`.
        # @param string [Object] The string to write (`to_s` will be called
        #                        before writing).
        # @param options [Hash] Optional parameters (`:autoclose`, `:block_size`
        #                       and `:small`).
        # @return [Integer] The number of uncompressed bytes written.
        # @raise [ArgumentError] If `io_or_path` is _not_ a `String`, `Pathname`
        #                        or an `IO`-like object with a `write` method.
        # @raise [Errno::ENOENT] If the parent directory of the specified file
        #                        does not exist.
        # @raise [Error::Bzip2Error] If an error occurs when initializing
        #                            libbz2 or compressing data.
        def write(io_or_path, string, options = {})
          open(io_or_path, options) do |writer|
            writer.write(string)
          end
        end

        private

        # Returns a Proc that can be used as a finalizer to call
        # `BZ2_bzCompressEnd` with the given `stream`.
        #
        # @param stream [Libbz2::BzStream] The stream that should be passed to
        #                                  `BZ2_bzCompressEnd`.
        def finalize(stream)
          ->(id) do
            Libbz2::BZ2_bzCompressEnd(stream)
          end
        end
      end

      # Initializes a {Writer} to write compressed data to an `IO`-like object
      # (`io`). `io` must have a `write` method.
      #
      # The following options can be specified using the `options` `Hash`:
      #
      # * `:autoclose` - When passing an `IO`-like object, set to `true` to
      #                  close the `IO` when the `Writer` instance is closed.
      # * `:block_size` - Specifies the block size used for compression. It
      #                   should be set to an integer between 1 and 9
      #                   inclusive. The actual block size used is 100 kB
      #                   times the chosen figure. 9 gives the best
      #                   compression, but requires most memory. 1 gives the
      #                   worst compression, but uses least memory. If not
      #                   specified, `:block_size` defaults to 9.
      # * `:work_factor` - Controls how the compression algorithm behaves
      #                    when presented with the worst case, highly
      #                    repetitive, input data. If compression runs into
      #                    difficulties caused by repetitive data, the
      #                    library switches from the standard sorting
      #                    algorithm to a fallback algorithm. The fallback is
      #                    slower than the standard algorithm by approximately
      #                    a factor of three, but always behaves reasonably,
      #                    no matter how bad the input. Lower values of
      #                    `:work_factor` reduce the amount of effort the
      #                    standard algorithm will expend before resorting to
      #                    the fallback. Allowable values range from 0 to 250
      #                    inclusive. 0 is a special case, equivalent to using
      #                    the default libbz2 work factor value (30 as of
      #                    bzip2 v1.0.6). If not specified, `:work_factor`
      #                    defaults to 0.
      #
      # `binmode` is called on `io` if `io` responds to `binmode`.
      #
      # After use, the `Writer` instance must be closed using the {#close}
      # method in order to complete the compression process.
      #
      # @param io [Object] An `IO`-like object that has a `write` method.
      # @param options [Hash] Optional parameters (`:autoclose`, `:block_size`
      #                       and `:small`).
      # @raise [ArgumentError] If `io` is `nil` or does not respond to `write`.
      # @raise [RangeError] If `options[:block_size]` is less than 1 or greater
      #                     than 9, or `options[:work_factor]` is less than 0 or
      #                     greater than 250.
      # @raise [Error::Bzip2Error] If an error occurs when initializing libbz2.
      def initialize(io, options = {})    
        super
        raise ArgumentError, 'io must respond to write' unless io.respond_to?(:write)
        
        block_size = options[:block_size] || 9
        work_factor = options[:work_factor] || 0
        
        raise RangeError, 'block_size must be >= 1 and <= 9' if block_size < 1 || block_size > 9
        raise RangeError, 'work_factor must be >= 0 and <= 250' if work_factor < 0 || work_factor > 250
        
        check_error(Libbz2::BZ2_bzCompressInit(stream, block_size, 0, work_factor))

        ObjectSpace.define_finalizer(self, self.class.send(:finalize, stream))
      end

      # Completes compression of data written using {#write}, writes all
      # remaining compressed bytes to the underlying stream and closes the
      # {Writer}.
      #
      # If the {open} method is used with a block, it is not necessary to call
      # `close`. Otherwise, `close` must be called once the all the data to be
      # compressed has been passed to `#write`.
      #
      # @return [NilType] `nil`.
      # @raise [IOError] If the `Writer` has already been closed.
      def close
        s = stream
        flush_buffers(s, Libbz2::BZ_FINISH, Libbz2::BZ_STREAM_END)
        res = Libbz2::BZ2_bzCompressEnd(s)
        ObjectSpace.undefine_finalizer(self)
        check_error(res)
        super
      end

      # Compresses data from a `String` and writes it to the bzip2 compressed
      # stream or file.
      #
      # No character conversion is performed. The raw bytes from `string` are
      # compressed (using the encoding of `string`).
      #
      # The number of uncompressed bytes written is returned.
      #
      # @param string [Object] The string to write (`to_s` will be called
      #                        before writing).
      # @return [Integer] The number of uncompressed bytes written.
      # @raise [Error::Bzip2Error] If an error occurs during compression.
      # @raise [IOError] If the `Writer` has been closed.
      def write(string)
        string = string.to_s

        s = stream
        next_in = ::FFI::MemoryPointer.new(1, string.bytesize)
        buffer = ::FFI::MemoryPointer.new(1, OUT_BUFFER_SIZE)
        begin
          next_in.write_bytes(string)
          s[:next_in] = next_in        
          s[:avail_in] = next_in.size

          while s[:avail_in] > 0
            s[:next_out] = buffer
            s[:avail_out] = buffer.size

            check_error(Libbz2::BZ2_bzCompress(s, Libbz2::BZ_RUN))

            count = buffer.size - s[:avail_out]
            io.write(buffer.read_string(count))
          end
        ensure
          next_in.free
          buffer.free
          s[:next_in] = nil
          s[:next_out] = nil
        end

        string.bytesize
      end

      # Completes compression of data provided via {#write}, terminates and
      # writes out the current bzip2 compressed block to the underlying
      # compressed stream or file.
      #
      # It is not usually necessary to call `flush`.
      #
      # Calling `flush` may result in a larger compressed output.
      #
      # @return [Writer] `self`.
      # @raise [Error::Bzip2Error] If an error occurs during the flush
      #                            operation.
      # @raise [IOError] If the `Writer` has been closed.
      def flush
        flush_buffers(stream, Libbz2::BZ_FLUSH, Libbz2::BZ_RUN_OK)
        self
      end

      private

      # Calls `BZ2_bzCompress` repeatedly without input to complete compression
      # of data that has been provided in prior calls.
      #
      # @param s [Libbz2::BzStream] The stream to pass to `BZ2_bzCompress`.
      # @param action [Integer] The action to pass to `BZ2_bzCompress`.
      # @param terminate_result [Integer] The result code that indicates when
      #                                   the action has been completed.
      # @raise [Error::Bzip2Error] If `BZ2_bzCompress` reports an error.
      def flush_buffers(s, action, terminate_result)
        s[:next_in] = nil
        s[:avail_in] = 0

        buffer = ::FFI::MemoryPointer.new(1, OUT_BUFFER_SIZE)
        begin
          loop do
            s[:next_out] = buffer
            s[:avail_out] = buffer.size

            res = Libbz2::BZ2_bzCompress(s, action)
            check_error(res)

            count = buffer.size - s[:avail_out]
            io.write(buffer.read_string(count))

            break if res == terminate_result
          end
        ensure
          buffer.free
          s[:next_out] = nil
        end
      end     
    end
  end
end
