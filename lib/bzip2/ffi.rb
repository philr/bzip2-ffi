# encoding: UTF-8
# frozen_string_literal: true

module Bzip2
  # Bzip2::FFI is a wrapper for libbz2 using FFI bindings. Bzip2 compressed data
  # can be read and written as a stream using the Reader and Writer classes.
  module FFI
  end
end

require_relative 'ffi/libbz2'
require_relative 'ffi/error'
require_relative 'ffi/io'
require_relative 'ffi/reader'
require_relative 'ffi/writer'
require_relative 'ffi/version'

