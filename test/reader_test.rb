require 'fileutils'
require 'pathname'
require 'stringio'
require 'test_helper'
require 'tmpdir'

class ReaderTest < Minitest::Test
  class StringIOWithoutSeek < StringIO
    undef_method :seek
  end

  def setup
    Bzip2::FFI::Reader.test_after_open_file_raise_exception = false
  end

  def teardown
    Bzip2::FFI::Reader.test_after_open_file_raise_exception = false
    Bzip2::FFI::Reader.test_after_open_file_last_io = nil
  end

  def compare_fixture(reader, fixture, read_size = nil, use_outbuf = nil)
    File.open(fixture_path(fixture), 'rb') do |input|
      if read_size
        loop do
          buffer = input.read(read_size)
          
          if use_outbuf          
            outbuf = 'outbuf'
            decompressed = reader.read(read_size, outbuf)

            if decompressed
              assert_same(outbuf, decompressed)
            else
              assert_equal('', outbuf)
            end
          else
            decompressed = reader.read(read_size)
          end

          if buffer
            assert_same(Encoding::ASCII_8BIT, decompressed.encoding)
            assert_equal(buffer, decompressed)
          else
            assert_nil(decompressed)
            break
          end
        end        
      else
        buffer = input.read

        if use_outbuf
          outbuf = 'outbuf'
          decompressed = reader.read(nil, outbuf)
          assert_same(outbuf, decompressed)
        else
          decompressed = reader.read
        end
        
        refute_nil(decompressed)
        assert_same(Encoding::ASCII_8BIT, decompressed.encoding)
        assert_equal(buffer, decompressed)      
      end

      assert_nil(reader.read(1))
      assert_equal(0, reader.read.bytesize)
    end
  end

  def bzip_test(fixture, options = {})
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      uncompressed = File.join(dir, 'test')
      if fixture
        FileUtils.cp(fixture_path(fixture), uncompressed)
      else
        FileUtils.touch(uncompressed)
      end
      
      assert_bzip2_successful(uncompressed)
    
      compressed = File.join(dir, "test.bz2")
      assert(File.exist?(compressed))

      Bzip2::FFI::Reader.open(compressed, options[:reader_options] || {}) do |reader|
        if fixture
          compare_fixture(reader, fixture, options[:read_size], options[:use_outbuf])
        else
          assert_equal(0, reader.read.bytesize)
        end
      end
    end    
  end

  def test_initialize_nil_io
    assert_raises(ArgumentError) { Bzip2::FFI::Reader.new(nil) }
  end

  def test_initialize_io_with_no_read_method
    assert_raises(ArgumentError) { Bzip2::FFI::Reader.new(Object.new) }
  end

  def test_empty
    bzip_test(nil)
  end

  def test_fixture_text
    [16, 1024, 16384, File.size(fixture_path('lorem.txt')), nil].each do |read_size|
      [false, true].each do |use_outbuf|
        bzip_test('lorem.txt', read_size: read_size, use_outbuf: use_outbuf)
      end
    end    
  end

  def test_fixture_very_compressible
    [16, 1024, 16384, File.size(fixture_path('zero.txt')), nil].each do |read_size|
      [false, true].each do |use_outbuf|
        bzip_test('zero.txt', read_size: read_size, use_outbuf: use_outbuf)
      end
    end
  end

  def test_fixture_uncompressible
    [16, 1024, 16384, File.size(fixture_path('bzipped')), nil].each do |read_size|
      [false, true].each do |use_outbuf|
        bzip_test('bzipped', read_size: read_size, use_outbuf: use_outbuf)
      end
    end
  end

  def test_fixture_image
    [16, 1024, 16384, File.size(fixture_path('moon.tiff')), nil].each do |read_size|
      [false, true].each do |use_outbuf|
        bzip_test('moon.tiff', read_size: read_size, use_outbuf: use_outbuf)
      end
    end    
  end

  def test_small
    # Not trivial to check if the value passed has any effect. Just check that
    # there are no failures.
    [false, true].each do |small|
      bzip_test('lorem.txt', reader_options: {small: small})
    end
  end

  def test_close_mid_read
    Bzip2::FFI::Reader.open(fixture_path('bzipped')) do |reader|
      decompressed = reader.read(1)
      refute_nil(decompressed)
      assert_equal(1, decompressed.bytesize)
    end
  end

  def test_read_zero_before_eof
    Bzip2::FFI::Reader.open(fixture_path('bzipped')) do |reader|
      decompressed = reader.read(0)
      refute_nil(decompressed)
      assert_equal(0, decompressed.bytesize)
    end
  end

  def test_read_zero_before_eof_buffer
    Bzip2::FFI::Reader.open(fixture_path('bzipped')) do |reader|
      buffer = 'outbuf'
      decompressed = reader.read(0, buffer)
      assert_same(buffer, decompressed)
      assert_equal(0, decompressed.bytesize)
    end
  end

  def test_read_zero_after_eof
    Bzip2::FFI::Reader.open(fixture_path('bzipped')) do |reader|
      reader.read
      decompressed = reader.read(0) # would return nil if greater than 0
      refute_nil(decompressed)
      assert_equal(0, decompressed.bytesize)
    end
  end

  def test_read_zero_after_eof_buffer
    Bzip2::FFI::Reader.open(fixture_path('bzipped')) do |reader|
      reader.read
      buffer = 'outbuf'
      decompressed = reader.read(0, buffer) # would return nil if greater than 0
      assert_same(buffer, decompressed)
      assert_equal(0, decompressed.bytesize)
    end
  end

  def test_read_after_close_read_all
    File.open(fixture_path('bzipped'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read }
    end
  end

  def test_read_after_close_read_all_buffer
    File.open(fixture_path('bzipped'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read(nil, '') }
    end
  end

  def test_read_after_close_read_n
    File.open(fixture_path('bzipped'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read(1) }
    end
  end

  def test_read_after_close_read_n_buffer
    File.open(fixture_path('bzipped'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read(1, '') }
    end
  end

  def test_read_after_close_read_zero
    File.open(fixture_path('bzipped'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read(0) }
    end
  end

  def test_read_after_close_read_zero_buffer
    File.open(fixture_path('bzipped'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read(0, '') }
    end
  end

  def test_close_returns_nil
    reader = Bzip2::FFI::Reader.new(StringIO.new)
    assert_nil(reader.close)
  end

  def test_non_bzipped
    Bzip2::FFI::Reader.open(fixture_path('lorem.txt')) do |reader|
      assert_raises(Bzip2::FFI::Error::MagicDataError) { reader.read }
    end
  end

  def test_truncated_bzip
    [1024, Bzip2::FFI::Reader::READ_BUFFER_SIZE, 8192].each do |size|
      partial = StringIO.new

      File.open(fixture_path('bzipped'), 'rb') do |input|
        buffer = input.read(size)
        refute_nil(buffer)
        assert_equal(size, buffer.bytesize)
        partial.write(buffer)
      end

      partial.seek(0)
      
      Bzip2::FFI::Reader.open(partial) do |reader|
        assert_raises(Bzip2::FFI::Error::UnexpectedEofError) { reader.read }
      end
    end
  end

  def test_corrupted_bzip
    corrupted = StringIO.new

    File.open(fixture_path('bzipped'), 'rb') do |file|
      corrupted.write(file.read)
    end    

    corrupted.seek(4000)
    corrupted.write("\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")

    corrupted.seek(0)

    Bzip2::FFI::Reader.open(corrupted) do |reader|
      assert_raises(Bzip2::FFI::Error::DataError) { reader.read }
    end
  end

  def test_data_after_compressed
    suffixed = StringIO.new

    File.open(fixture_path('bzipped'), 'rb') do |file|
      suffixed.write(file.read)
    end

    suffixed.write('Test')

    suffixed.seek(0)

    Bzip2::FFI::Reader.open(suffixed) do |reader|
      assert_equal(65670, reader.read.bytesize)
      assert_nil(reader.read(1))
      assert_equal(0, reader.read.bytesize)
    end
    
    assert_equal('Test', suffixed.read)
  end

  def test_data_after_compressed_no_seek
    suffixed = StringIO.new

    File.open(fixture_path('bzipped'), 'rb') do |file|
      suffixed.write(file.read)
    end

    suffixed.write('Test')

    suffixed.seek(0)

    class << suffixed
      undef_method :seek
    end

    Bzip2::FFI::Reader.open(suffixed) do |reader|
      assert_equal(65670, reader.read.bytesize)
      assert_nil(reader.read(1))
      assert_equal(0, reader.read.bytesize)
    end    

    # For this input, the suffix will already have been consumed before the
    # end of the bzip2 stream is reached. There is no seek method, so it is not
    # possible to restore the position to the end of the bzip2 stream.
    assert_equal(0, suffixed.read.bytesize)
  end

  def test_data_after_compressed_seek_raises_io_error
    suffixed = StringIO.new

    File.open(fixture_path('bzipped'), 'rb') do |file|
      suffixed.write(file.read)
    end

    suffixed.write('Test')

    suffixed.seek(0)

    def suffixed.seek(amount, whence = IO::SEEK_SET)
      raise IOError, 'Cannot seek'
    end

    Bzip2::FFI::Reader.open(suffixed) do |reader|
      assert_equal(65670, reader.read.bytesize)
      assert_nil(reader.read(1))
      assert_equal(0, reader.read.bytesize)
    end    

    # For this input, the suffix will already have been consumed before the
    # end of the bzip2 stream is reached. There is no seek method, so it is not
    # possible to restore the position to the end of the bzip2 stream.
    assert_equal(0, suffixed.read.bytesize)
  end

  def test_finalizer
    # Code coverage will verify that the finalizer was called.
    10.times { Bzip2::FFI::Reader.new(StringIO.new) }
    GC.start
  end

  def test_open_io_nil
    assert_raises(ArgumentError) { Bzip2::FFI::Reader.open(nil) }
  end

  def test_open_io_with_no_read_method
    assert_raises(ArgumentError) { Bzip2::FFI::Reader.open(Object.new) }
  end

  def test_open_block_io
    io = StringIO.new
    Bzip2::FFI::Reader.open(io, autoclose: true) do |reader|
      assert_same(io, reader.send(:io))
      assert_equal(true, reader.autoclose?)
    end
  end

  def test_open_no_block_io
    io = StringIO.new
    reader = Bzip2::FFI::Reader.open(io, autoclose: true)
    begin
      assert_same(io, reader.send(:io))
      assert_equal(true, reader.autoclose?)
    ensure
      reader.close
    end
  end

  def test_open_block_path
    path = fixture_path('bzipped')
    [path, Pathname.new(path)].each do |path_param|
      Bzip2::FFI::Reader.open(path_param) do |reader|
        io = reader.send(:io)
        assert_kind_of(File, io)
        assert_equal(path, io.path)
        assert_raises(IOError) { io.write('test') }
        assert_nothing_raised { io.read(1) }
      end
    end
  end

  def test_open_no_block_path
    path = fixture_path('bzipped')
    [path, Pathname.new(path)].each do |path_param|
      reader = Bzip2::FFI::Reader.open(path_param)
      begin
        io = reader.send(:io)
        assert_kind_of(File, io)
        assert_equal(path, io.path)
        assert_raises(IOError) { io.write('test') }
        assert_nothing_raised { io.read(1) }
      ensure
        io.close
      end
    end
  end

  def test_open_block_path_always_autoclosed
    Bzip2::FFI::Reader.open(fixture_path('bzipped'), autoclose: false) do |reader|    
      assert_equal(true, reader.autoclose?)
    end
  end

  def test_open_no_block_path_always_autoclosed
    reader = Bzip2::FFI::Reader.open(fixture_path('bzipped'), autoclose: false)
    begin
      assert_equal(true, reader.autoclose?)
    ensure
      reader.close
    end
  end

  def test_open_path_does_not_exist
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      assert_raises(Errno::ENOENT) { Bzip2::FFI::Reader.open(File.join(dir, 'test')) }
    end
  end

  def test_open_proc_not_allowed
    assert_raises(ArgumentError) { Bzip2::FFI::Reader.open(-> { StringIO.new }) }
  end

  def test_open_after_open_file_exception_closes_file
    Bzip2::FFI::Reader.test_after_open_file_raise_exception = true
    assert_raises(RuntimeError) { Bzip2::FFI::Reader.open(fixture_path('bzipped')) }
    file = Bzip2::FFI::Reader.test_after_open_file_last_io
    refute_nil(file)
    assert(file.closed?)
  end

  def test_class_read_initialize_nil_io
    assert_raises(ArgumentError) { Bzip2::FFI::Reader.read(nil) }
  end

  def test_class_read_io_with_no_read_method
    assert_raises(ArgumentError) { Bzip2::FFI::Reader.read(Object.new) }
  end

  def class_read_test(content)
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      uncompressed = File.join(dir, 'test')
      File.write(uncompressed, content)
      assert_bzip2_successful(uncompressed)
      compressed = File.join(dir, 'test.bz2')
      result = yield compressed
      assert_equal(content, result)
      assert_same(Encoding::ASCII_8BIT, result.encoding)
    end
  end

  def test_class_read_io
    class_read_test('test_io') do |compressed|
      File.open(compressed, 'rb') do |file|
        Bzip2::FFI::Reader.read(file, {})
      end
    end
  end

  def test_class_read_path
    class_read_test('test_path') do |compressed|
      Bzip2::FFI::Reader.read(compressed)
    end
  end

  def test_class_read_pathname
    class_read_test('test_pathname') do |compressed|
      Bzip2::FFI::Reader.read(Pathname.new(compressed))
    end
  end

  def test_class_read_path_file_does_not_exist
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      assert_raises(Errno::ENOENT) { Bzip2::FFI::Reader.read(File.join(dir, 'test')) }
    end
  end
end
