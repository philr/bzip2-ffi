# encoding: UTF-8
# frozen_string_literal: true

require 'pathname'
require 'stringio'

module Bzip2
  module FFI
    # {Reader} reads and decompresses a bzip2 compressed stream or file. The
    # public instance methods of {Reader} are intended to be equivalent to those
    # of a standard `IO` object.
    #
    # Data can be read as a stream using {open} and {#read}, for example:
    #
    #     Bzip2::FFI::Reader.open(io_or_path) do |reader|
    #       while buffer = reader.read(1024) do
    #         # process uncompressed bytes in buffer
    #       end
    #     end
    #
    # Alternatively, without passing a block to {open}:
    #
    #     reader = Bzip2::FFI::Reader.open(io_or_path)
    #     begin
    #       while buffer = reader.read(1024) do
    #         # process uncompressed bytes in buffer
    #       end
    #     ensure
    #       reader.close
    #     end
    #
    # All the available bzipped data can be read in a single step using {read}:
    #
    #     uncompressed = Bzip2::FFI::Reader.read(io_or_path)
    #
    # The {open} and {read} methods accept either an IO-like object or a file
    # path. IO-like objects must have a `#read` method. Paths can be given as
    # either a `String` or `Pathname`.
    #
    # No character conversion is performed on decompressed bytes. The {read} and
    # {#read} methods return instances of `String` that represent the raw
    # decompressed bytes, with `#encoding` set to `Encoding::ASCII_8BIT` (also
    # known as `Encoding::BINARY`).
    #
    # {Reader} will normally read all consecutive bzip2 compressed structure
    # from the given stream or file (unless the `:first_only` parameter is
    # specified - see {open}). If the stream or file contains additional data
    # beyond the end of the compressed bzip2 data, it may be read during
    # decompression. If such an overread has occurred and the IO-like object
    # being read from has a `#seek` method, {Reader} will use it to reposition
    # the stream to the byte immediately following the end of the compressed
    # bzip2 data. If `#seek` raises an `IOError`, it will be caught and the
    # stream position will be left unchanged.
    #
    # {Reader} does not support seeking (it's not supported by the underlying
    # libbz2 library). There are no `#seek` or `#pos=` methods. The only way to
    # advance the position is to call {#read}. Discard the result if it's not
    # needed.
    class Reader < IO
      # The number of bytes read from the compressed data stream at a time.
      #
      # @private
      READ_BUFFER_SIZE = 4096 #:nodoc:
      private_constant :READ_BUFFER_SIZE

      # The number of uncompressed bytes to read at a time when using {#read}
      # without a length.
      #
      # @private
      DEFAULT_DECOMPRESS_COUNT = 4096 #:nodoc:
      private_constant :DEFAULT_DECOMPRESS_COUNT

      class << self
        # Use send to keep this hidden from YARD (visibility tag does not work).
        send(:public, :new)

        # Opens a {Reader} to read and decompress data from either an IO-like
        # object or a file. IO-like objects must have a `#read` method. Files
        # can be specified using either a `String` containing the file path or a
        # `Pathname`.
        #
        # If no block is given, the opened {Reader} instance is returned. After
        # use, the instance should be closed using the {#close} method.
        #
        # If a block is given, it will be passed the opened {Reader} instance
        # as an argument. After the block terminates, the {Reader} instance will
        # automatically be closed. {open} will then return the result of the
        # block.
        #
        # The following options can be specified using the `options` `Hash`:
        #
        # * `:autoclose` - When passing an IO-like object, set to `true` to
        #                  close it when the {Reader} instance is closed.
        # * `:first_only` - Bzip2 files can contain multiple consecutive
        #                   compressed strctures. Normally all the structures
        #                   will be decompressed with the decompressed bytes
        #                   concatenated. Set to `true` to only read the first
        #                   structure.
        # * `:small` - Set to `true` to use an alternative decompression
        #              algorithm that uses less memory, but at the cost of
        #              decompressing more slowly (roughly 2,300 kB less memory
        #              at about half the speed).
        #
        # If an IO-like object that has a `#binmode` method is passed to {open},
        # `#binmode` will be called on `io_or_path` before yielding to the block
        # or returning.
        #
        # @param io_or_path [Object] Either an IO-like object with a `#read`
        #                            method or a file path as a `String` or
        #                            `Pathname`.
        # @param options [Hash] Optional parameters (`:autoclose` and `:small`).
        # @yield [reader] If a block is given, it is yielded to.
        # @yieldparam reader [Reader] The new {Reader} instance.
        # @yieldresult [Object] A result to be returned as the result of {open}.
        # @return [Object] The opened {Reader} instance if no block is given, or
        #                  the result of the block if a block is given.
        # @raise [ArgumentError] If `io_or_path` is _not_ a `String`, `Pathname`
        #                        or an IO-like object with a `#read` method.
        # @raise [Errno::ENOENT] If the specified file does not exist.
        # @raise [Error::Bzip2Error] If an error occurs when initializing
        #                            libbz2.
        def open(io_or_path, options = {})
          if io_or_path.kind_of?(String) || io_or_path.kind_of?(Pathname)
            options = options.merge(autoclose: true)
            proc = -> { open_bzip_file(io_or_path.to_s, 'rb') }
            super(proc, options)
          elsif !io_or_path.kind_of?(Proc)
            super
          else
            raise ArgumentError, 'io_or_path must be an IO-like object or a path'
          end
        end

        # Reads and decompresses data from the bzip2 compressed stream or file
        # and yields each line to the block. The block is called with each line
        # as a `String`.
        #
        # The following options can be specified using the `options` `Hash`:
        #
        # * `:autoclose` - When passing an IO-like object, set to `true` to
        #                  close it when the compressed data has been read.
        # * `:first_only` - Bzip2 files can contain multiple consecutive
        #                   compressed strctures. Normally all the structures
        #                   will be decompressed with the decompressed bytes
        #                   concatenated. Set to `true` to only read the first
        #                   structure.
        # * `:small` - Set to `true` to use an alternative decompression
        #              algorithm that uses less memory, but at the cost of
        #              decompressing more slowly (roughly 2,300 kB less memory
        #              at about half the speed).
        #
        # If an IO-like object that has a `#binmode` method is passed to {foreach},
        # `#binmode` will be called on `io_or_path` before any compressed data
        # is read.
        #
        # @param io_or_path [Object] Either an IO-like object with a `#read`
        #                            method or a file path as a `String` or
        #                            `Pathname`.
        # @param options [Hash] Optional parameters (`:autoclose`, `:first_only`
        #                       and `:small`).
        # @yield [line] The block is called with each line as a `String`.
        # @yieldparam line [String] A line of decompressed data.
        # @return [NilType] `nil`.
        # @raise [ArgumentError] If `io_or_path` is _not_ a `String`, `Pathname`
        #                        or an IO-like object with a `#read` method.
        # @raise [Errno::ENOENT] If the specified file does not exist.
        # @raise [Error::Bzip2Error] If an error occurs when initializing
        #                            libbz2 or decompressing data.
        def foreach(io_or_path, options = {})
          open(io_or_path, options) do |reader|
            buffer = +""
            until reader.eof?
              buffer << reader.read
              lines = buffer.split("\n")
              lines[0...-1].each { |line| yield line }
              buffer = lines.last
            end
            yield buffer unless buffer.empty?
          end
        end

        # Reads and decompresses and entire bzip2 compressed structure from
        # either an IO-like object or a file and returns the decompressed bytes
        # as a `String`. IO-like objects must have a `#read` method. Files can
        # be specified using either a `String` containing the file path or a
        # `Pathname`.
        #
        # The following options can be specified using the `options` `Hash`:
        #
        # * `:autoclose` - When passing an IO-like object, set to `true` to
        #                  close it when the compressed data has been read.
        # * `:first_only` - Bzip2 files can contain multiple consecutive
        #                   compressed strctures. Normally all the structures
        #                   will be decompressed with the decompressed bytes
        #                   concatenated. Set to `true` to only read the first
        #                   structure.
        # * `:small` - Set to `true` to use an alternative decompression
        #              algorithm that uses less memory, but at the cost of
        #              decompressing more slowly (roughly 2,300 kB less memory
        #              at about half the speed).
        #
        # No character conversion is performed on decompressed bytes. {read}
        # returns a `String` that represents the raw decompressed bytes, with
        # `encoding` set to `Encoding::ASCII_8BIT` (also known as
        # `Encoding::BINARY`).
        #
        # If an IO-like object that has a `#inmode` method is passed to {read},
        # `#binmode` will be called on `io_or_path` before any compressed data
        # is read.
        #
        # @param io_or_path [Object] Either an IO-like object with a `#read`
        #                            method or a file path as a `String` or
        #                            `Pathname`.
        # @param options [Hash] Optional parameters (`:autoclose`, `:first_only`
        #                       and `:small`).
        # @return [String] The decompressed data.
        # @raise [ArgumentError] If `io_or_path` is _not_ a `String`, `Pathname`
        #                        or an IO-like object with a `#read` method.
        # @raise [Errno::ENOENT] If the specified file does not exist.
        # @raise [Error::Bzip2Error] If an error occurs when initializing
        #                            libbz2 or decompressing data.
        def read(io_or_path, options = {})
          open(io_or_path, options) do |reader|
            reader.read
          end
        end

        private

        # Returns a `Proc` that can be used as a finalizer to call
        # {Libbz2::BZ2_bzDecompressEnd} with the given `stream`.
        #
        # @param stream [Libbz2::BzStream] The stream that should be passed to
        #                                  {Libbz2::BZ2_bzDecompressEnd}.
        def finalize(stream)
          ->(id) do
            Libbz2::BZ2_bzDecompressEnd(stream)
          end
        end
      end

      # Initializes a {Reader} to read compressed data from an IO-like object
      # (`io`). `io` must have a `#read` method.
      #
      # The following options can be specified using the `options` `Hash`:
      #
      # * `:autoclose` - Set to `true` to close `io` when the {Reader} instance
      #                  is closed.
      # * `:first_only` - Bzip2 files can contain multiple consecutive
      #                   compressed strctures. Normally all the structures will
      #                   be decompressed with the decompressed bytes
      #                   concatenated. Set to `true` to only read the first
      #                   structure.
      # * `:small` - Set to `true` to use an alternative decompression
      #              algorithm that uses less memory, but at the cost of
      #              decompressing more slowly (roughly 2,300 kB less memory
      #              at about half the speed).
      #
      # `#binmode` is called on `io` if `io` responds to `#binmode`.
      #
      # After use, the {Reader} instance should be closed using the {#close}
      # method.
      #
      # @param io [Object] An IO-like object with a `#read` method.
      # @param options [Hash] Optional parameters (`:autoclose`, `:first_only`
      #                       and `:small`).
      # @raise [ArgumentError] If `io` is `nil` or does not respond to `#read`.
      # @raise [Error::Bzip2Error] If an error occurs when initializing libbz2.
      def initialize(io, options = {})
        super
        raise ArgumentError, 'io must respond to read' unless io.respond_to?(:read)

        @first_only = options[:first_only]
        @small = options[:small] ? 1 : 0

        @in_eof = false
        @out_eof = false
        @in_buffer = nil
        @structure_number = 1
        @structure_start_pos = 0
        @in_pos = 0
        @out_pos = 0

        decompress_init(stream)
      end

      # Ends decompression and closes the {Reader}.
      #
      # If the {open} method is used with a block, it is not necessary to call
      # {#close}. Otherwise, {#close} should be called once the {Reader} is no
      # longer needed.
      #
      # @return [NilType] `nil`.
      # @raise [IOError] If the {Reader} has already been closed.
      def close
        s = stream

        unless @out_eof
          decompress_end(s)
        end

        s[:next_in] = nil
        s[:next_out] = nil

        if @in_buffer
          @in_buffer.free
          @in_buffer = nil
        end

        super
      end

      # Reads and decompresses data from the bzip2 compressed stream or file,
      # returning the uncompressed bytes.
      #
      # `length` must be a non-negative integer or `nil`.
      #
      # If `length` is a positive integer, it specifies the maximum number of
      # uncompressed bytes to return. `read` will return `nil` or a `String`
      # with a length of 1 to `length` bytes containing the decompressed data.
      # A result of `nil` or a `String` with a length less than `length` bytes
      # indicates that the end of the decompressed data has been reached.
      #
      # If `length` is `nil`, {#read} reads until the end of the decompressed
      # data, returning the uncompressed bytes as a `String`.
      #
      # If `length` is 0, {#read} returns an empty `String`.
      #
      # If the optional `buffer` argument is present, it must reference a
      # `String` that will receive the decompressed data. `buffer` will
      # contain only the decompressed data after the call to {#read}, even if it
      # is not empty beforehand.
      #
      # No character conversion is performed on decompressed bytes. {#read}
      # returns a `String` that represents the raw decompressed bytes, with
      # `encoding` set to `Encoding::ASCII_8BIT` (also known as
      # `Encoding::BINARY`).
      #
      # @param length [Integer] Must be a non-negative integer or `nil`. Set to
      #                         a positive integer to specify the maximum number
      #                         of uncompressed bytes to return. Set to `nil` to
      #                         return the remaining decompressed data. Set to
      #                         0 to return an empty `String`.
      # @param buffer [String] An optional buffer to receive the decompressed
      #                        data.
      # @return [String] The decompressed data as a `String` with ASCII-8BIT
      #                  encoding, or `nil` if length was a positive integer and
      #                  the end of the decompressed data has been reached.
      # @raise [ArgumentError] If `length` is negative.
      # @raise [Error::Bzip2Error] If an error occurs during decompression.
      # @raise [IOError] If the {Reader} has been closed.
      def read(length = nil, buffer = nil)
        if buffer
          buffer.clear
          buffer.force_encoding(Encoding::ASCII_8BIT)
        end

        if length
          raise ArgumentError 'length must be a non-negative integer or nil' if length < 0

          if length == 0
            check_closed
            return buffer || String.new
          end

          decompressed = decompress(length)

          return nil unless decompressed
          buffer ? buffer << decompressed : decompressed
        else
          result = buffer ? StringIO.new(buffer) : StringIO.new

          # StringIO#binmode is a no-op, but call in case it is implemented in
          # future versions.
          result.binmode

          result.set_encoding(Encoding::ASCII_8BIT)

          loop do
            decompressed = decompress(DEFAULT_DECOMPRESS_COUNT)
            break unless decompressed
            result.write(decompressed)
            break if decompressed.bytesize < DEFAULT_DECOMPRESS_COUNT
          end

          result.string
        end
      end

      # Returns `true` if decompression has completed, otherwise `false`.
      #
      # Note that it is possible for `false` to be returned after all the
      # decompressed data has been read. In such cases, the next call to {#read}
      # will detect the end of the bzip2 structure and set {#eof?} to `true`.
      #
      # @return [Boolean] If decompression has completed, otherwise `false`.
      # @raise [IOError] If the {Reader} has been closed.
      def eof?
        check_closed
        @out_eof
      end
      alias eof eof?

      # Returns the number of decompressed bytes that have been read.
      #
      # @return [Integer] The number of decompressed bytes that have been read.
      # @raise [IOError] If the {Reader} has been closed.
      def tell
        check_closed
        @out_pos
      end
      alias pos tell

      private

      # Attempts to decompress and return `count` bytes.
      #
      # @param count [Integer] The number of uncompressed bytes to return (must
      #                        be a positive integer).
      # @return [String] The decompressed data as a `String` with ASCII-8BIT
      #                  encoding, or `nil` if length was a positive integer and
      #                  the end of the decompressed data has been reached.
      # @raise [ArgumentError] If `count` is not greater than or equal to 1.
      # @raise [Error::Bzip2Error] If an error occurs during decompression.
      # @raise [IOError] If the {Reader} has been closed.
      def decompress(count)
        raise ArgumentError, "count must be a positive integer" unless count >= 1
        s = stream
        return nil if @out_eof

        out_buffer = ::FFI::MemoryPointer.new(1, count)
        begin
          s[:next_out] = out_buffer
          s[:avail_out] = out_buffer.size

          # Decompress data until count bytes have been read, or the end of
          # the stream is reached.
          loop do
            if s[:avail_in] == 0 && !@in_eof
              bytes = io.read(READ_BUFFER_SIZE)

              if bytes && bytes.bytesize > 0
                @in_pos += bytes.bytesize
                @in_eof = bytes.bytesize < READ_BUFFER_SIZE
                @in_buffer = ::FFI::MemoryPointer.new(1, bytes.bytesize)
                @in_buffer.write_bytes(bytes)
                s[:next_in] = @in_buffer
                s[:avail_in] = @in_buffer.size
              else
                @in_eof = true
              end
            end

            # Reached the end of input without reading anything in the current
            # bzip2 structure. No more data to process.
            if @in_pos == @structure_start_pos
              @out_eof = true
              break
            end

            prev_avail_out = s[:avail_out]

            res = Libbz2::BZ2_bzDecompress(s)

            if s[:avail_in] == 0 && @in_buffer
              s[:next_in] = nil
              @in_buffer.free
              @in_buffer = nil
            end

            if @structure_number > 1 && res == Libbz2::BZ_DATA_ERROR_MAGIC
              # Found something other than the bzip2 magic bytes after the end
              # of a bzip2 structure.
              #
              # Attempt to move the input stream back by the amount that has
              # been over-read.
              attempt_seek_to_structure_start
              decompress_end(s)
              @out_eof = true
              break
            end

            check_error(res)

            if res == Libbz2::BZ_STREAM_END
              decompress_end(s)

              if (s[:avail_in] > 0 || !@in_eof) && !@first_only
                # Re-initialize to read a second bzip2 structure if there is
                # still input available and not restricting to the first stream.
                @structure_number += 1
                @structure_start_pos = @in_pos - s[:avail_in]
                decompress_init(s)
              else
                # May have already read data after the end of the first bzip2
                # structure.
                attempt_seek_to_structure_start if @first_only
                @out_eof = true
                break
              end
            else
              # No more input available and calling BZ2_bzDecompress didn't
              # advance the output. Raise an error.
              if @in_eof && s[:avail_in] == 0 && prev_avail_out == s[:avail_out]
                decompress_end(s)
                @out_eof = true
                raise Error::UnexpectedEofError.new
              end
            end

            break if s[:avail_out] == 0
          end

          result = out_buffer.read_bytes(out_buffer.size - s[:avail_out])
        ensure
          out_buffer.free
          s[:next_out] = nil
          s[:avail_out] = 0
        end

        if @out_eof && result.bytesize == 0
          nil
        else
          @out_pos += result.bytesize
          result
        end
      end

      # Attempts to reposition the compressed stream to the start of the current
      # structure. Used when {Libbz2::BZ2_bzDecompress} has read beyond the end
      # of a bzip2 structure.
      def attempt_seek_to_structure_start
        if io.respond_to?(:seek)
          diff = @structure_start_pos - @in_pos
          if diff < 0
            begin
              io.seek(diff, ::IO::SEEK_CUR)
              @in_pos += diff
            rescue IOError
            end
          end
        end
      end

      # Calls {Libbz2::BZ2_bzDecompressInit} to initialize the decompression
      # stream `s`.
      #
      # Defines a finalizer to ensure that the memory associated with the stream
      # is deallocated.
      #
      # @param s [Libbz2::BzStream] The stream to initialize decompression for.
      # @raise [Error::Bzip2Error] If {Libbz2::BZ2_bzDecompressInit} reports an
      #                            error.
      def decompress_init(s)
        check_error(Libbz2::BZ2_bzDecompressInit(s, 0, @small))

        ObjectSpace.define_finalizer(self, self.class.send(:finalize, s))
      end

      # Calls {Libbz2::BZ2_bzDecompressEnd} to release memory associated with
      # the decompression stream `s`.
      #
      # Notifies `ObjectSpace` that it is no longer necessary to finalize the
      # {Reader} instance.
      #
      # @param s [Libbz2::BzStream] The stream to end decompression for.
      # @raise [Error::Bzip2Error] If {Libbz2::BZ2_bzDecompressEnd} reports an
      #                            error.
      def decompress_end(s)
        res = Libbz2::BZ2_bzDecompressEnd(s)
        ObjectSpace.undefine_finalizer(self)
        check_error(res)
      end
    end
  end
end
