module Bzip2
  module FFI
    class BzStreamIO
      class << self
        protected :new

        protected
      
        def open(io, options = {})
          bz_io = new(io, options)

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
        @io.close if autoclose?
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
