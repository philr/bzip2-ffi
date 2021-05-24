# Bzip2::FFI

[![RubyGems](https://img.shields.io/gem/v/bzip2-ffi?logo=rubygems&label=Gem)](https://rubygems.org/gems/bzip2-ffi) [![Tests](https://github.com/philr/bzip2-ffi/workflows/Tests/badge.svg?branch=master&event=push)](https://github.com/philr/bzip2-ffi/actions?query=workflow%3ATests+branch%3Amaster+event%3Apush) [![Coverage Status](https://img.shields.io/coveralls/github/philr/bzip2-ffi/master?label=Coverage&logo=Coveralls)](https://coveralls.io/github/philr/bzip2-ffi?branch=master)

Bzip2::FFI is a Ruby wrapper for libbz2 using FFI bindings.

The Bzip2::FFI Reader and Writer classes support reading and writing bzip2
compressed data as an `IO`-like stream.


## Installation

The Bzip2::FFI gem can be installed by running `gem install bzip2-ffi` or by
adding `gem 'bzip2-ffi'` to your `Gemfile` and running `bundle install`.


## Compatibility

Bzip2::FFI requires a minimum of Ruby MRI 1.9.3 or JRuby 1.7 (in 1.9 mode or
later).


## Runtime Dependencies

Bzip2::FFI is a pure-Ruby library that uses
[Ruby-FFI](https://rubygems.org/gems/ffi) (Foreign Function Interface) to load
the libbz2 dynamic library at runtime.

libbz2 is available as a package on most UNIX-based systems (for example,
`libbz2-1.0` on Debian and Ubuntu, or `bzip2-libs` on Fedora, Red Hat, and
CentOS).


### Windows

On Windows, you will need to have `libbz2.dll` or `bz2.dll` available on the
`PATH` or in the Ruby `bin` directory.

Suitable builds of `libbz2.dll` are available from the
[bzip2-windows project](https://github.com/philr/bzip2-windows/releases).
Download the DLL only package that matches your Ruby installation (x86 or x64)
and extract to your `ruby\bin` directory.

Builds from the bzip2-windows project depend on the Visual Studio C Runtime
Library. Links to the installer can be found on the bzip2-windows release page.


## Usage

To use Bzip2::FFI, it must first be loaded with:

```ruby
require 'bzip2/ffi'
```


### Compressing

Data can be compressed using the `Bzip2::FFI::Writer` class. For example, the
following compresses lines read from `ARGF` (either standard input, or file
names given as command-line arguments:

```ruby
Bzip2::FFI::Writer.open(io_or_path) do |writer|
  ARGF.each_line do |line|
    writer.write(line)
  end
end
```

Alternatively, without passing a block to `open`:

```ruby
writer = Bzip2::FFI::Writer.open(io_or_path)
begin
  ARGF.each_line do |line|
    writer.write(line)
  end
ensure
  writer.close
end
```

An entire bzip2 structure can also be written in a single step:

```ruby
Bzip2::FFI::Writer.write(io_or_path, 'Hello, World!')
```

In each of the examples above, `io_or_path` can either be a path to a file to
write to or an `IO`-like object that has a `#write` method.


### Decompressing

Data can be decompressed using the `Bzip2::FFI::Reader` class. For example:

```ruby
Bzip2::FFI::Reader.open(io_or_path) do |reader|
  while buffer = reader.read(1024) do
    # process uncompressed bytes in buffer
  end
end
```

Alternatively, without passing a block to `open`:

```ruby
reader = Bzip2::FFI::Reader.open(io_or_path)
begin
  while buffer = reader.read(1024) do
    # process uncompressed bytes in buffer
  end
ensure
  reader.close
end
```

All the available bzipped data can be read and decompressed in a single step:

```ruby
uncompressed = Bzip2::FFI::Reader.read(io_or_path)
```

In each of the examples above, `io_or_path` can either be a path to a file to
read from or an `IO`-like object that has a `#read` method.


### Character Encoding

Bzip2::FFI does not perform any encoding conversion when reading or writing.
Data read using `Bzip2::FFI::Reader` is returned as `String` instances with
ASCII-8BIT (BINARY) encoding representing the raw decompressed bytes.
`Bzip2::FFI::Writer` compresses the raw bytes from the `String` instances passed
to the `#write` method (using the encoding of the `String`).


### Streaming and Memory Usage

Bzip2::FFI compresses and decompresses data as a stream, allowing large files to
be handled without requiring the complete contents to be held in memory.

When decompressing, 4 KB of compressed data is read at a time. An additional 4
KB is required to pass the data to libbz2. Decompressed data is output in blocks
dictated by the length passed to `Bzip2::FFI::Reader#read` (defaulting to 4 KB
and requiring twice the length in memory to read from libbz2).

When compressing, up to 4 KB of compressed data is written at a time, requiring
up to 8 KB of memory. An additional copy is also taken of the `String` passed to
`Bzip2::FFI::Writer#write`.

Internally, libbz2 allocates additional memory according to the bzip2 block
size. Please refer to the
[Memory Management](https://sourceware.org/bzip2/manual/manual.html#memory-management)
section of the Bzip2 documentation for details.


## Documentation

Documentation for Bzip2::FFI is available on
[RubyDoc.info](https://www.rubydoc.info/gems/bzip2-ffi).


## License

Bzip2::FFI is distributed under the terms of the MIT license. A copy of this
license can be found in the included LICENSE file.


## GitHub Project

Source code, release information and the issue tracker can be found on the
[Bzip2::FFI GitHub project page](https://github.com/philr/bzip2-ffi).
