# encoding: UTF-8

require 'pathname'
require 'test_helper'
require 'tmpdir'

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

  def write_io(writer, io, read_size = nil)
    if read_size
      loop do
        buffer = io.read(read_size)
        break unless buffer
        assert_equal(buffer.bytesize, writer.write(buffer))
      end
    else
      buffer = io.read
      assert_equal(buffer.bytesize, writer.write(buffer))
    end
  end

  def write_fixture(writer, fixture, read_size = nil)
    File.open(fixture_path(fixture), 'rb') do |input|
      write_io(writer, input, read_size)
    end
  end

  def bunzip_test(fixture_or_strings, options = {})  
    Dir.mktmpdir('bzip2-ffi-test') do |dir|      
      compressed = File.join(dir, "test.bz2")
      Bzip2::FFI::Writer.open(compressed, options[:writer_options] || {}) do |writer|
        if fixture_or_strings
          if fixture_or_strings.kind_of?(Array)
            fixture_or_strings.each do |string|
              assert_equal(string.bytesize, writer.write(string))
            end
          else
            write_fixture(writer, fixture_or_strings, options[:read_size])
          end
        end
      end

      assert_bunzip2_successful(compressed)

      uncompressed = File.join(dir, 'test')
      assert(File.exist?(uncompressed))

      if fixture_or_strings
        if fixture_or_strings.kind_of?(Array)
          File.open(uncompressed, 'rb') do |file|
            fixture_or_strings.each do |string|
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

  def test_fixture_text
    [16, 1024, 16384, nil].each do |read_size|
      bunzip_test('lorem.txt', read_size: read_size)
    end
  end

  def test_fixture_very_compressible
    [16, 1024, 16384, nil].each do |read_size|
      bunzip_test('zero.txt', read_size: read_size)
    end
  end

  def test_fixture_uncompressible
    [16, 1024, 16384, nil].each do |read_size|
      bunzip_test('bzipped', read_size: read_size)
    end
  end

  def test_fixture_image
    [16, 1024, 16384, nil].each do |read_size|
      bunzip_test('moon.tiff', read_size: read_size)
    end    
  end

  def test_encoding_handling
    bunzip_test(['áÁçÇðÐéÉ'.encode(Encoding::UTF_8), 'áÁçÇðÐéÉ'.encode(Encoding::ISO_8859_1)])
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

  def test_work_factor
    # Not trivial to check if the value passed has any effect. Just check that
    # there are no failures for values within the acceptable range.

    [0, 100, 250].each do |work_factor|
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

  def test_finalizer
    # Code coverage will verify that the finalizer was called.
    10.times { Bzip2::FFI::Writer.new(DummyIO.new) }
    GC.start
  end

  def test_open_io_nil
    assert_raises(ArgumentError) { Bzip2::FFI::Writer.open(nil) }
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

  def test_open_block_path
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      path = File.join(dir, 'test')
      [path, Pathname.new(path)].each do |path_param|
        Bzip2::FFI::Writer.open(path_param) do |writer|
          io = writer.send(:io)
          assert_kind_of(File, io)
          assert_equal(path, io.path)
          assert_raises(IOError) { io.read(1) }
          assert_nothing_raised { io.write('test') }
        end
      end
    end
  end

  def test_open_no_block_path
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      path = File.join(dir, 'test')
      [path, Pathname.new(path)].each do |path_param|
        writer = Bzip2::FFI::Writer.open(path_param)
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
end
