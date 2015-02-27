# Bzip2::FFI #

[![Gem Version](https://badge.fury.io/rb/bzip2-ffi.svg)](http://badge.fury.io/rb/bzip2-ffi) [![Build Status](https://travis-ci.org/philr/bzip2-ffi.svg?branch=master)](https://travis-ci.org/philr/bzip2-ffi) [![Coverage Status](https://coveralls.io/repos/philr/bzip2-ffi/badge.svg?branch=master)](https://coveralls.io/r/philr/bzip2-ffi?branch=master)

Bzip2::FFI is a Ruby wrapper for libbz2 using FFI bindings.

The Bzip2::FFI Reader and Writer classes support reading and writing bzip2
compressed data as an `IO`-like stream.


## Installation ##

To install the Bzip2::FFI gem, run the following command:

    gem install bzip2-ffi

To add Bzip2::FFI as a Bundler dependency, add the following line to your
`Gemfile`:

    gem 'bzip2-ffi'


## Compatibility ##

Bzip2::FFI is tested on Ruby MRI 1.9.3+, JRuby 1.7+ and Rubinius 2+.


## Runtime Dependencies ##

Bzip2::FFI is a pure-Ruby library that uses
[Ruby-FFI](https://rubygems.org/gems/ffi) (Foreign Function Interface) to load
the libbz2 dynamic library at runtime.

libbz2 is available as a package on most UNIX-based systems (for example,
`libbz2-1.0` on Debian and Ubuntu, or `bzip2-libs` on Fedora, Red Hat, and
CentOS).


### Windows ###

On Windows, you will need to have `libbz2.dll` or `bz2.dll` available on the
`PATH` or in the Ruby `bin` directory.

Suitable builds of `libbz2.dll` are available from the
[bzip2-windows project](https://github.com/philr/bzip2-windows/releases).
Download the DLL only package that matches your Ruby installation (x86 or x64)
and extract to your `ruby\bin` directory.

Builds from the bzip2-windows project depend on the Visual Studio 2013 C Runtime
Library (msvcr120.dll). This can be installed using the
[Visual C++ Redistributable Packages for Visual Studio 2013 installer](http://www.microsoft.com/en-gb/download/details.aspx?id=40784).


## Usage ##

To use Bzip2::FFI, it must first be loaded with:

    require 'bzip2/ffi'


### Compressing ###

Data can be compressed using the `Bzip2::FFI::Writer` class. For example, the
following compresses lines read from standard input (`ARGF`):

    Bzip2::FFI::Writer.open(io_or_path) do |writer|
      ARGF.each_line do |line|
        writer.write(line)
      end
    end

Alternatively, without passing a block to `open`:

    writer = Bzip2::FFI::Writer.open(io_or_path)
    begin
      ARGF.each_line do |line|
        writer.write(line)
      end
    ensure
      writer.close
    end

An entire bzip2 structure can also be written in a single step:

    Bzip2::FFI::Writer.write(io_or_path, 'Hello, World!')

In each of the examples above, `io_or_path` can either be a path to a file to
write to or an `IO`-like object that has a `write` method.


### Decompressing ###

Data can be decompressed using the `Bzip2::FFI::Reader` class. For example:

    Bzip2::FFI::Reader.open(io_or_path) do |reader|
      while buffer = reader.read(1024) do
        # process uncompressed bytes in buffer
      end
    end

Alternatively, without passing a block to `open`:

    reader = Bzip2::FFI::Reader.open(io_or_path)
    begin
      while buffer = reader.read(1024) do
        # process uncompressed bytes in buffer
      end
    ensure
      reader.close
    end

An entire bzip2 structure can be read and decompressed in a single step:

    uncompressed = Bzip2::FFI::Reader.read(io_or_path)

In each of the examples above, `io_or_path` can either be a path to a file to
read from or an `IO`-like object that has a `read` method.


### Character Encoding ###

Bzip2::FFI does not perform any encoding conversion when reading or writing.
Data read using `Bzip2::FFI::Reader` is returned as `String` instances with
ASCII-8BIT (BINARY) encoding representing the raw decompressed bytes.
`Bzip2::FFI::Writer` compresses the raw bytes from the `Strings` passed to the
`write` method (using the encoding of the `String`).


## Documentation ##

Documentation for Bzip2::FFI is available on
[RubyDoc.info](http://www.rubydoc.info/gems/bzip2-ffi).


## License ##

Bzip2::FFI is distributed under the terms of the MIT license. A copy of this
license can be found in the included LICENSE file.


## GitHub Project ##

Source code, release information and the issue tracker can be found on the
[Bzip2::FFI GitHub project page](https://github.com/philr/bzip2-ffi).
