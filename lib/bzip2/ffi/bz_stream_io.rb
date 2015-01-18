module Bzip2
  module FFI
    class BzStreamIO
      class << self
        protected :new

        protected
      
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
              bz_io.close
            end
          else
            bz_io
          end
        end

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

        def after_open_file(io)
          # JRuby 1.7.18 doesn't have a File#advise method (in any mode).
          if io.respond_to?(:advise)
            io.advise(:sequential)
            io.advise(:noreuse)
          end
        end
      end
    
      def autoclose?
        @autoclose
      end

      def autoclose=(autoclose)
        @autoclose = !!autoclose
      end
      
      def binmode?
        true
      end

      def binmode
        self
      end

      def close
        @io.close if autoclose? && @io.respond_to?(:close)
        @stream = nil
      end

      def closed?
        !@stream
      end

      def external_encoding
        Encoding::ASCII_8BIT
      end

      def internal_encoding
        Encoding::ASCII_8BIT
      end
      
      protected

      attr_reader :io
      
      def initialize(io, options = {})
        raise ArgumentError, 'io is required' unless io
        
        @io = io
        @io.binmode if @io.respond_to?(:binmode)        

        @autoclose = !!options[:autoclose]
        
        @stream = Libbz2::BzStream.new
      end

      def stream
        raise IOError, 'closed stream' unless @stream
        @stream
      end      

      def check_error(res)
        raise Error.new(res) if res < 0
        res
      end      
    end
  end
end
