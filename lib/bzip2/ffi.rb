module Bzip2
  # Bzip2::FFI is a wrapper for libbz2 using FFI bindings. Bzip2 compressed data
  # can be read and written as a stream using the Reader and Writer classes.
  module FFI
  end
end

require 'bzip2/ffi/libbz2'
require 'bzip2/ffi/error'
require 'bzip2/ffi/io'
require 'bzip2/ffi/reader'
require 'bzip2/ffi/writer'
require 'bzip2/ffi/version'

