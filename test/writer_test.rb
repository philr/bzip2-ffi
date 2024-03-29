# encoding: UTF-8
# frozen_string_literal: true

require 'tmpdir'
require_relative 'test_helper'

class WriterTest < Minitest::Test
  class DummyIO
    attr_reader :written_bytes

    def initialize
      @written_bytes = 0
    end

    def write(string)
      @written_bytes += string.bytesize
    end
  end

  class << self
    def read_size_combinations(fixture)
      [16, 1024, 16384, File.size(fixture_path(fixture)), nil].each do |read_size|
        yield read_size, "#{read_size ? "_with_read_size_#{read_size}" : ''}"
      end
    end

    def bunzip_fixture_tests(name, fixture)
      read_size_combinations(fixture) do |read_size, description|
        define_method("test_fixture_#{name}#{description}") do
          bunzip_test(fixture, read_size: read_size)
        end
      end
    end
  end

  def setup
    Bzip2::FFI::Writer.test_after_open_file_raise_exception = false
  end

  def teardown
    Bzip2::FFI::Writer.test_after_open_file_raise_exception = false
    Bzip2::FFI::Writer.test_after_open_file_last_io = nil
  end

  def write_io(writer, io, read_size = nil)
    if read_size
      loop do
        buffer = io.read(read_size)
        break unless buffer
        assert_equal(buffer.bytesize, writer.write(buffer))
        assert_equal(io.tell, writer.tell)
        assert_equal(io.pos, writer.pos)
      end
    else
      buffer = io.read
      assert_equal(buffer.bytesize, writer.write(buffer))
      assert_equal(io.tell, writer.tell)
      assert_equal(io.pos, writer.pos)
    end
  end

  def write_fixture(writer, fixture, read_size = nil)
    File.open(fixture_path(fixture), 'rb') do |input|
      write_io(writer, input, read_size)
    end
  end

  def bunzip_and_compare(compressed, fixture_or_strings)
    assert_bunzip2_successful(compressed)

    uncompressed = compressed.chomp('.bz2')
    assert(File.exist?(uncompressed))

    if fixture_or_strings
      if fixture_or_strings.kind_of?(Array)
        File.open(uncompressed, 'rb') do |file|
          fixture_or_strings.each do |string|
            string = string.to_s
            buffer = file.read(string.bytesize)
            refute_nil(buffer)
            assert_equal(string.bytesize, buffer.bytesize)
            assert_equal(string.bytes.to_a, buffer.bytes.to_a)
          end

          assert_nil(file.read(1))
        end
      else
        assert_files_identical(fixture_path(fixture_or_strings), uncompressed)
      end
    else
      assert_equal(0, File.size(uncompressed))
    end
  end

  def bunzip_test(fixture_or_strings, options = {})
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      compressed = File.join(dir, "test.bz2")
      Bzip2::FFI::Writer.open(compressed, options[:writer_options] || {}) do |writer|
        if fixture_or_strings
          if fixture_or_strings.kind_of?(Array)
            fixture_or_strings.each do |string|
              assert_equal(string.to_s.bytesize, writer.write(string))
            end
          else
            write_fixture(writer, fixture_or_strings, options[:read_size])
          end
        end
      end

      bunzip_and_compare(compressed, fixture_or_strings)
    end
  end

  def test_initialize_nil_io
    assert_raises(ArgumentError) { Bzip2::FFI::Writer.new(nil) }
  end

  def test_initialize_io_with_no_write_method
    assert_raises(ArgumentError) { Bzip2::FFI::Writer.new(Object.new) }
  end

  def test_initialize_invalid_block_size
    assert_raises(RangeError) { Bzip2::FFI::Writer.new(DummyIO.new, block_size: 0) }
    assert_raises(RangeError) { Bzip2::FFI::Writer.new(DummyIO.new, block_size: 10) }
  end

  def test_initialize_invalid_work_factor
    assert_raises(RangeError) { Bzip2::FFI::Writer.new(DummyIO.new, work_factor: -1) }
    assert_raises(RangeError) { Bzip2::FFI::Writer.new(DummyIO.new, work_factor: 251) }
  end

  def test_no_write
    bunzip_test(nil)
  end

  bunzip_fixture_tests(:text, 'lorem.txt')
  bunzip_fixture_tests(:very_compressible, 'zero.txt')
  bunzip_fixture_tests(:uncompressible, 'compressed.bz2')
  bunzip_fixture_tests(:image, 'moon.tiff')

  def test_encoding_handling
    bunzip_test(['áÁçÇðÐéÉ'.encode(Encoding::UTF_8), 'áÁçÇðÐéÉ'.encode(Encoding::ISO_8859_1)])
  end

  def test_write_non_string
    bunzip_test([:test, 42])
  end

  def test_block_size
    sizes = [1, 9].collect do |block_size|
      io = DummyIO.new

      Bzip2::FFI::Writer.open(io, block_size: block_size) do |writer|
        write_fixture(writer, 'lorem.txt')
      end

      io.written_bytes
    end

    assert(sizes.last < sizes.first, 'compressed size with block_size = 1 is not less than compressed size with block_size = 9')
  end

  def test_default_block_size
    # The default block size should be 9. Check that the size of the compressed
    # stream for the default block size is the same as the size when compressed
    # with :block_size set to 9.

    explicit_io = DummyIO.new
    Bzip2::FFI::Writer.open(explicit_io, block_size: 9) do |writer|
      write_fixture(writer, 'lorem.txt')
    end

    default_io = DummyIO.new
    Bzip2::FFI::Writer.open(default_io) do |writer|
      write_fixture(writer, 'lorem.txt')
    end

    assert_equal(explicit_io.written_bytes, default_io.written_bytes)
  end

  [0, 100, 250].each do |work_factor|
    define_method("test_work_factor_#{work_factor}") do
      bunzip_test('lorem.txt', writer_options: {work_factor: work_factor})
    end
  end

  def test_write_after_close
    writer = Bzip2::FFI::Writer.new(DummyIO.new)
    writer.close
    assert_raises(IOError) { writer.write('test') }
  end

  def test_flush
    non_flushed = DummyIO.new
    flushed = DummyIO.new

    Bzip2::FFI::Writer.open(non_flushed) do |writer|
      write_fixture(writer, 'lorem.txt', 4096)
    end

    Bzip2::FFI::Writer.open(flushed) do |writer|
      File.open(fixture_path('lorem.txt'), 'rb') do |fixture|
        5.times do
          buffer = fixture.read(4096)
          assert_equal(4096, buffer.bytesize)
          assert_equal(4096, writer.write(buffer))
        end

        assert_same(writer, writer.flush)

        write_io(writer, fixture, 4096)
      end
    end

    # Flushed stream will be larger because it forces libbz2 to terminate the
    # current compression block earlier that it would otherwise do.
    assert(flushed.written_bytes > non_flushed.written_bytes, 'flushed Writer did not create a larger output')
  end

  def test_flush_after_close
    writer = Bzip2::FFI::Writer.new(DummyIO.new)
    writer.close
    assert_raises(IOError) { writer.flush }
  end

  def test_close_returns_nil
    writer = Bzip2::FFI::Writer.new(DummyIO.new)
    assert_nil(writer.close)
  end

  [:tell, :pos].each do |method|
    define_method("test_#{method}_returns_uncompressed_position") do
      Bzip2::FFI::Writer.open(DummyIO.new) do |writer|
        assert_equal(0, writer.public_send(method))
        writer.write('Test')
        assert_equal(4, writer.public_send(method))
        writer.write('Complete')
        assert_equal(12, writer.public_send(method))
      end
    end

    define_method("test_#{method}_returns_uncompressed_64bit_position") do
      skip_slow_test_unless_enabled

      # The position is read from separate 32-bit low and high words.
      Bzip2::FFI::Writer.open(DummyIO.new) do |writer|
        buffer_bits = 12
        buffer = "\0".encode(Encoding::ASCII_8BIT) * 2**buffer_bits

        (2**(32 - buffer_bits)).times do |i|
          writer.write(buffer)
        end

        assert_equal(2**32, writer.public_send(method))
        writer.write(buffer)
        assert_equal(2**32 + buffer.bytesize, writer.public_send(method))
      end
    end

    define_method("test_#{method}_raises_io_error_when_closed") do
      writer = Bzip2::FFI::Writer.new(DummyIO.new)
      writer.close
      assert_raises(IOError) { writer.public_send(method) }
    end
  end

  def test_finalizer
    # Code coverage will verify that the finalizer was called.
    10.times { Bzip2::FFI::Writer.new(DummyIO.new) }
    GC.start
  end

  def test_open_io_nil
    assert_raises(ArgumentError) { Bzip2::FFI::Writer.open(nil) }
  end

  def test_open_io_with_no_write_method
    assert_raises(ArgumentError) { Bzip2::FFI::Writer.open(Object.new) }
  end

  [0, 10].each do |block_size|
    define_method("test_open_invalid_block_size_#{block_size}") do
      assert_raises(RangeError) { Bzip2::FFI::Writer.open(DummyIO.new, block_size: block_size) }
    end
  end

  [-1, 251].each do |work_factor|
    define_method("test_open_invalid_work_factor_#{work_factor}") do
      assert_raises(RangeError) { Bzip2::FFI::Writer.open(DummyIO.new, work_factor: work_factor) }
    end
  end

  def test_open_block_io
    io = DummyIO.new
    Bzip2::FFI::Writer.open(io, autoclose: true) do |writer|
      assert_same(io, writer.send(:io))
      assert_equal(true, writer.autoclose?)
    end
  end

  def test_open_no_block_io
    io = DummyIO.new
    writer = Bzip2::FFI::Writer.open(io, autoclose: true)
    begin
      assert_same(io, writer.send(:io))
      assert_equal(true, writer.autoclose?)
    ensure
      writer.close
    end
  end

  path_or_pathname_tests(:open_block) do |path_param|
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      path = File.join(dir, 'test')
      Bzip2::FFI::Writer.open(path_param.call(path)) do |writer|
        io = writer.send(:io)
        assert_kind_of(File, io)
        assert_equal(path, io.path)
        assert_raises(IOError) { io.read(1) }
        assert_nothing_raised { io.write('test') }
      end
    end
  end

  path_or_pathname_tests(:open_no_block) do |path_param|
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      path = File.join(dir, 'test')
      writer = Bzip2::FFI::Writer.open(path_param.call(path))
      begin
        io = writer.send(:io)
        assert_kind_of(File, io)
        assert_equal(path, io.path)
        assert_raises(IOError) { io.read(1) }
        assert_nothing_raised { io.write('test') }
      ensure
        writer.close
      end
    end
  end

  def test_open_block_path_always_autoclosed
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      Bzip2::FFI::Writer.open(File.join(dir, 'test'), autoclose: false) do |writer|
        assert_equal(true, writer.autoclose?)
      end
    end
  end

  def test_open_no_block_path_always_autoclosed
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      writer = Bzip2::FFI::Writer.open(File.join(dir, 'test'), autoclose: false)
      begin
        assert_equal(true, writer.autoclose?)
      ensure
        writer.close
      end
    end
  end

  def test_open_parent_dir_does_not_exist
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      assert_raises(Errno::ENOENT) { Bzip2::FFI::Writer.open(File.join(dir, 'test_dir', 'test_file')) }
    end
  end

  def test_open_existing_file_truncated
    plain_content = 'This is not a bzip'
    compressed_content = 'This is a bzip'

    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      path = File.join(dir, 'test.bz2')

      File.write(path, 'This is not a bzip')

      File.open(path, 'rb') do |file|
        assert_equal(plain_content, file.read(plain_content.bytesize))
      end

      Bzip2::FFI::Writer.open(path) do |writer|
        writer.write(compressed_content)
      end

      File.open(path, 'rb') do |file|
        refute_equal(plain_content, file.read(plain_content.bytesize))
      end

      bunzip_and_compare(path, [compressed_content])
    end
  end

  def test_open_proc_not_allowed
    assert_raises(ArgumentError) { Bzip2::FFI::Writer.open(-> { StringIO.new }) }
  end

  def test_open_after_open_file_exception_closes_file
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      Bzip2::FFI::Writer.test_after_open_file_raise_exception = true
      assert_raises(RuntimeError) { Bzip2::FFI::Writer.open(File.join(dir, 'test')) }
      file = Bzip2::FFI::Writer.test_after_open_file_last_io
      refute_nil(file)
      assert(file.closed?)
    end
  end

  def test_class_write_nil_io
    assert_raises(ArgumentError) { Bzip2::FFI::Writer.write(nil, 'test') }
  end

  def test_class_write_io_with_no_write_method
    assert_raises(ArgumentError) { Bzip2::FFI::Writer.write(Object.new, 'test') }
  end

  def test_class_write_invalid_block_size
    assert_raises(RangeError) { Bzip2::FFI::Writer.write(DummyIO.new, 'test', block_size: 0) }
    assert_raises(RangeError) { Bzip2::FFI::Writer.write(DummyIO.new, 'test', block_size: 10) }
  end

  def test_class_write_invalid_work_factor
    assert_raises(RangeError) { Bzip2::FFI::Writer.write(DummyIO.new, 'test', work_factor: -1) }
    assert_raises(RangeError) { Bzip2::FFI::Writer.write(DummyIO.new, 'test', work_factor: 251) }
  end

  def class_write_test(content)
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      compressed = File.join(dir, 'test.bz2')
      result = yield compressed, content
      assert_equal(content.bytesize, result)
      bunzip_and_compare(compressed, [content])
    end
  end

  def test_class_write_io
    class_write_test('test_io') do |compressed, content|
      File.open(compressed, 'wb') do |file|
        Bzip2::FFI::Writer.write(file, content)
      end
    end
  end

  path_or_pathname_tests(:class_write) do |path_param|
    class_write_test('test_path') do |compressed, content|
      Bzip2::FFI::Writer.write(path_param.call(compressed), content)
    end
  end

  def test_class_write_path_not_exist
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      assert_raises(Errno::ENOENT) { Bzip2::FFI::Writer.write(File.join(dir, 'test_dir', 'test_file'), 'test') }
    end
  end

  def test_class_write_existing_file_truncated
    plain_content = 'This is not a bzip'
    compressed_content = 'This is a bzip'

    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      path = File.join(dir, 'test.bz2')
      File.write(path, 'This is not a bzip')
      assert_equal(plain_content, File.read(path, plain_content.bytesize))
      Bzip2::FFI::Writer.write(path, compressed_content)
      refute_equal(plain_content, File.read(path, plain_content.bytesize))
      bunzip_and_compare(path, [compressed_content])
    end
  end
end
