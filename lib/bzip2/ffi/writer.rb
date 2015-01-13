require 'pathname'

module Bzip2
  module FFI
    class Writer < BzStreamIO
      OUT_BUFFER_SIZE = 4096      

      class << self
        public :new

        def open(io_or_path, options = {})
          if io_or_path.kind_of?(String) || io_or_path.kind_of?(Pathname)
            options = options.merge(autoclose: true)
            proc = -> do
              io = File.open(io_or_path.to_s, 'wb')

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
            Libbz2::BZ2_bzCompressEnd(stream)
          end
        end
      end

      def initialize(io, options = {})    
        super
        raise ArgumentError, 'io must respond to write' unless io.respond_to?(:write)
        
        block_size = options[:block_size] || 1
        work_factor = options[:work_factor] || 0
        
        raise RangeError, 'block_size must be >= 1 and <= 9' if block_size < 1 || block_size > 9
        raise RangeError, 'work_factor must be >= 0 and <= 250' if work_factor < 0 || work_factor > 250
        
        check_error(Libbz2::BZ2_bzCompressInit(stream, block_size, 0, work_factor))

        ObjectSpace.define_finalizer(self, self.class.send(:finalize, stream))
      end

      def close
        s = stream
        flush_buffers(s, Libbz2::BZ_FINISH, Libbz2::BZ_STREAM_END)
        res = Libbz2::BZ2_bzCompressEnd(s)
        ObjectSpace.undefine_finalizer(self)
        check_error(res)
        super
      end

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

      def flush
        flush_buffers(stream, Libbz2::BZ_FLUSH, Libbz2::BZ_RUN_OK)
        self
      end

      private

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
