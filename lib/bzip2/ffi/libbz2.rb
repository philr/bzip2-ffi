require 'ffi'

module Bzip2
  module FFI
    # The libbzip2 low-level interface.
    module Libbz2
      extend ::FFI::Library

      ffi_lib ['bz2', 'libbz2.so.1', 'libbz2.dll']

      BZ_RUN    = 0
      BZ_FLUSH  = 1
      BZ_FINISH = 2

      BZ_OK               =  0
      BZ_RUN_OK           =  1
      BZ_FLUSH_OK         =  2
      BZ_FINISH_OK        =  3
      BZ_STREAM_END       =  4
      BZ_SEQUENCE_ERROR   = -1
      BZ_PARAM_ERROR      = -2
      BZ_MEM_ERROR        = -3
      BZ_DATA_ERROR       = -4
      BZ_DATA_ERROR_MAGIC = -5
      BZ_IO_ERROR         = -6
      BZ_UNEXPECTED_EOF   = -7
      BZ_OUTBUFF_FULL     = -8
      BZ_CONFIG_ERROR     = -9

      callback :bzalloc, [:pointer, :int, :int], :pointer
      callback :bzfree, [:pointer, :pointer], :void

      # bz_stream
      class BzStream < ::FFI::Struct
        layout :next_in,       :pointer,
               :avail_in,      :uint,
               :total_in_lo32, :uint,
               :total_in_hi32, :uint,

               :next_out,       :pointer,
               :avail_out,      :uint,
               :total_out_lo32, :uint,
               :total_out_hi32, :uint,

               :state,          :pointer,

               :bzalloc,        :bzalloc,
               :bzfree,         :bzfree,
               :opaque,         :pointer       
      end

      # int BZ2_bzCompressInt(bz_stream* strm, int blockSize100k, int verbosity, int workFactor)
      attach_function :BZ2_bzCompressInit, [BzStream.by_ref, :int, :int, :int], :int

      # int BZ2_bzCompress (bz_stream* strm, int action)
      attach_function :BZ2_bzCompress, [BzStream.by_ref, :int], :int

      # int BZ2_bzCompressEnd (bz_stream* strm)
      attach_function :BZ2_bzCompressEnd, [BzStream.by_ref], :int
      
      # int BZ2_bzDecompressInit (bz_stream *strm, int verbosity, int small)
      attach_function :BZ2_bzDecompressInit, [BzStream.by_ref, :int, :int], :int

      # int BZ2_bzDecompress (bz_stream* strm)
      attach_function :BZ2_bzDecompress, [BzStream.by_ref], :int

      # int BZ2_bzDecompressEnd (bz_stream *strm)
      attach_function :BZ2_bzDecompressEnd, [BzStream.by_ref], :int
    end
  end
end
