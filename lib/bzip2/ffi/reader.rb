require 'pathname'
require 'stringio'

module Bzip2
  module FFI
    class Reader < BzStreamIO
      READ_BUFFER_SIZE = 4096
      DEFAULT_DECOMPRESS_COUNT = 4096

      class << self
        public :new    

        def open(io_or_path, options = {})
          if io_or_path.kind_of?(String) || io_or_path.kind_of?(Pathname)
            options = options.merge(autoclose: true)
            proc = -> do
              io = File.open(io_or_path.to_s, 'rb')

              begin
                after_open_file(io)
              rescue
                io.close
                raise
              end

              io
            end

            super(proc, options)
          elsif !io_or_path.kind_of?(Proc)
            super
          else
            raise ArgumentError, 'io_or_path must be an IO-like object or a path'
          end
        end

        private

        def finalize(stream)
          ->(id) do
            Libbz2::BZ2_bzDecompressEnd(stream)
          end
        end
      end
    
      def initialize(io, options = {})
        super
        raise ArgumentError, 'io must respond to read' unless io.respond_to?(:read)

        small = options[:small]

        @in_eof = false
        @out_eof = false
        @in_buffer = nil

        check_error(Libbz2::BZ2_bzDecompressInit(stream, 0, small ? 1 : 0))

        ObjectSpace.define_finalizer(self, self.class.send(:finalize, stream))
      end

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

      def read(length = nil, buffer = nil)
        if buffer
          buffer.clear
          buffer.force_encoding(Encoding::ASCII_8BIT)
        end

        if length
          raise ArgumentError 'length must be a non-negative integer or nil' if length < 0

          if length == 0
            # Check the stream is still open (an exception will be raised if it
            # is closed).
            stream
            return buffer || ''
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

      private

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
                @in_eof = bytes.bytesize < READ_BUFFER_SIZE
                @in_buffer = ::FFI::MemoryPointer.new(1, bytes.bytesize)
                @in_buffer.write_bytes(bytes)
                s[:next_in] = @in_buffer
                s[:avail_in] = @in_buffer.size
              else
                @in_eof = true
              end
            end

            prev_avail_out = s[:avail_out]
            
            res = Libbz2::BZ2_bzDecompress(s)

            if s[:avail_in] == 0 && @in_buffer
              s[:next_in] = nil
              @in_buffer.free
              @in_buffer = nil
            end

            check_error(res)

            if res == Libbz2::BZ_STREAM_END
              # The input could contain data after the end of the bzip2 stream.
              # 
              # s[:avail_in] will contain the number of bytes that have been
              # read from io, but not been consumed by BZ2_bzDecompress.
              #
              # Attempt to move the input stream back by the amount that has
              # been over-read.
              if s[:avail_in] > 0 && io.respond_to?(:seek)
                io.seek(-s[:avail_in], IO::SEEK_CUR) rescue IOError
              end

              if @in_buffer
                s[:next_in] = nil
                @in_buffer.free
                @in_buffer = nil
              end

              decompress_end(s)
              
              @out_eof = true
              break
            end

            break if s[:avail_out] == 0

            # No more input available and calling BZ2_bzDecompress didn't
            # advance the output. Raise an error.
            if @in_eof && prev_avail_out == s[:avail_out]
              raise Error.new(Libbz2::BZ_UNEXPECTED_EOF)
            end
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
          result
        end        
      end

      def decompress_end(s)
        res = Libbz2::BZ2_bzDecompressEnd(s)
        ObjectSpace.undefine_finalizer(self)
        check_error(res)
      end
    end
  end
end
