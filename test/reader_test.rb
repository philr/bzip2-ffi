# encoding: UTF-8
# frozen_string_literal: true

require 'fileutils'
require 'stringio'
require 'tmpdir'
require_relative 'test_helper'

class ReaderTest < Minitest::Test
  class StringIOWithSeekCount < StringIO
    def seek_count
      instance_variable_defined?(:@seek_count) ? @seek_count : 0
    end

    def seek(amount, whence = IO::SEEK_SET)
      if instance_variable_defined?(:@seek_count)
        @seek_count += 1
      else
        @seek_count = 1
      end

      super
    end
  end

  class << self
    def read_size_and_use_outbuf_combinations(fixture)
      [16, 1024, 16384, File.size(fixture_path(fixture)), nil].each do |read_size|
        [false, true].each do |use_outbuf|
          yield read_size, use_outbuf, "#{read_size ? "_with_read_size_#{read_size}" : ''}#{use_outbuf ? '_using_outbuf' : ''}"
        end
      end
    end

    def bzip_fixture_tests(name, fixture)
      read_size_and_use_outbuf_combinations(fixture) do |read_size, use_outbuf, description|
        define_method("test_fixture_#{name}#{description}") do
          bzip_test(fixture, read_size: read_size, use_outbuf: use_outbuf)
        end
      end
    end
  end

  def setup
    Bzip2::FFI::Reader.test_after_open_file_raise_exception = false
  end

  def teardown
    Bzip2::FFI::Reader.test_after_open_file_raise_exception = false
    Bzip2::FFI::Reader.test_after_open_file_last_io = nil
  end

  def compare_fixture(reader, fixture, read_size = nil, use_outbuf = nil, limit = nil)
    File.open(fixture_path(fixture), 'rb') do |input|
      if read_size
        count = 0
        loop do
          next_read_size = limit ? [limit - count, read_size].min : read_size
          buffer = input.read(next_read_size)

          # Note that reader.eof? may not be true if buffer is nil -
          # BZ2_bzDecompress may not yet have had a chance to indicate
          # BZ_STREAM_END.
          if (buffer)
            assert_equal(false, reader.eof?)
            assert_equal(false, reader.eof)
          end

          if use_outbuf
            outbuf = 'outbuf'.dup
            decompressed = reader.read(read_size, outbuf)

            if decompressed
              assert_same(outbuf, decompressed)
            else
              assert_equal('', outbuf)
            end
          else
            decompressed = reader.read(read_size)
          end

          assert_equal(input.pos, reader.pos)

          if buffer
            refute_nil(decompressed)
            assert_same(Encoding::ASCII_8BIT, decompressed.encoding)
            assert_equal(buffer, decompressed)
            count += buffer.bytesize
            break if limit && count >= limit
          else
            assert_nil(decompressed)
            break
          end
        end
      else
        buffer = input.read
        buffer = buffer[0, limit] if limit

        if use_outbuf
          outbuf = 'outbuf'.dup
          decompressed = reader.read(nil, outbuf)
          assert_same(outbuf, decompressed)
        else
          decompressed = reader.read
        end

        assert_equal(buffer.bytesize, reader.pos)

        refute_nil(decompressed)
        assert_same(Encoding::ASCII_8BIT, decompressed.encoding)
        assert_equal(buffer, decompressed)
      end

      assert_equal(true, reader.eof?)
      assert_equal(true, reader.eof)
      assert_nil(reader.read(1))
      assert_equal(0, reader.read.bytesize)
    end
  end

  def bzip_test(fixture, options = {})
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      split_length = options[:split_length]
      split_files = nil
      uncompressed = File.join(dir, 'test')
      if fixture
        if split_length && split_length > 0
          File.open(fixture_path(fixture), 'rb') do |source|
            split_files = 0

            loop do
              buffer = source.read(split_length)
              buffer = '' if !buffer && split_files == 0
              break unless buffer

              split_files += 1
              File.open("#{uncompressed}.#{split_files}", 'wb') do |target|
                target.write(buffer)
              end
            end
          end
        else
          FileUtils.cp(fixture_path(fixture), uncompressed)
        end
      else
        FileUtils.touch(uncompressed)
      end

      compressed = "#{uncompressed}.bz2"

      if split_files
        File.open(compressed, 'wb') do |target|
          1.upto(split_files) do |i|
            split_file = "#{uncompressed}.#{i}"
            assert_bzip2_successful(split_file)
            File.open("#{split_file}.bz2", 'rb') do |source|
              target.write(source.read)
            end
          end
        end
      else
        assert_bzip2_successful(uncompressed)
      end

      assert(File.exist?(compressed))

      reader_options = options[:reader_options] || {}

      Bzip2::FFI::Reader.open(compressed, reader_options) do |reader|
        if fixture
          compare_fixture(reader, fixture, options[:read_size], options[:use_outbuf], reader_options[:first_only] ? split_length : nil)
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

  bzip_fixture_tests(:text, 'lorem.txt')
  bzip_fixture_tests(:very_compressible, 'zero.txt')
  bzip_fixture_tests(:uncompressible, 'compressed.bz2')
  bzip_fixture_tests(:image, 'moon.tiff')

  [false, true].each do |small|
    define_method("test_#{small ? '' : 'not_'}small") do
      # Not trivial to check if the value passed has any effect. Just check that
      # there are no failures.
      bzip_test('lorem.txt', reader_options: {small: small})
    end
  end

  read_size_and_use_outbuf_combinations('lorem.txt') do |read_size, use_outbuf, description|
    [16361, 16384, 32647, 32768].each do |split_length|
      [false, true].each do |first_only|
        define_method("test_multiple_bzip2_structures#{description}_with_split_length_#{split_length}#{first_only ? '_first_only' : ''}") do
          bzip_test('lorem.txt', read_size: read_size, use_outbuf: use_outbuf, split_length: split_length, reader_options: {first_only: first_only})
        end
      end
    end
  end

  def test_reads_all_when_first_bzip2_structure_ends_at_end_of_a_compressed_data_read
    # Tests s[:avail_in] reaching zero when in_eof is false.
    #
    # Requires a bzip2 fixture with a first structure that ends at the end of a
    # read from the compressed stream (read Bzip2::FFI::Reader::READ_BUFFER_SIZE
    # bytes at a time).

    assert_equal(0, 4096 % Bzip2::FFI::Reader.const_get(:READ_BUFFER_SIZE))
    result = Bzip2::FFI::Reader.read(fixture_path('lorem-first-structure-4096-bytes.txt.bz2'))
    expected = File.open(fixture_path('lorem.txt'), 'rb') {|f| f.read }
    assert_equal(expected, result)
  end

  def test_close_mid_read
    Bzip2::FFI::Reader.open(fixture_path('compressed.bz2')) do |reader|
      decompressed = reader.read(1)
      refute_nil(decompressed)
      assert_equal(1, decompressed.bytesize)
    end
  end

  def test_read_zero_before_eof
    Bzip2::FFI::Reader.open(fixture_path('compressed.bz2')) do |reader|
      decompressed = reader.read(0)
      refute_nil(decompressed)
      assert_equal(0, decompressed.bytesize)
      refute(decompressed.frozen?)
    end
  end

  def test_read_zero_before_eof_buffer
    Bzip2::FFI::Reader.open(fixture_path('compressed.bz2')) do |reader|
      buffer = 'outbuf'.dup
      decompressed = reader.read(0, buffer)
      assert_same(buffer, decompressed)
      assert_equal(0, decompressed.bytesize)
    end
  end

  def test_read_zero_after_eof
    Bzip2::FFI::Reader.open(fixture_path('compressed.bz2')) do |reader|
      reader.read
      decompressed = reader.read(0) # would return nil if greater than 0
      refute_nil(decompressed)
      assert_equal(0, decompressed.bytesize)
      refute(decompressed.frozen?)
    end
  end

  def test_read_zero_after_eof_buffer
    Bzip2::FFI::Reader.open(fixture_path('compressed.bz2')) do |reader|
      reader.read
      buffer = 'outbuf'.dup
      decompressed = reader.read(0, buffer) # would return nil if greater than 0
      assert_same(buffer, decompressed)
      assert_equal(0, decompressed.bytesize)
    end
  end

  def test_read_after_close_read_all
    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read }
    end
  end

  def test_read_after_close_read_all_buffer
    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read(nil, String.new) }
    end
  end

  def test_read_after_close_read_n
    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read(1) }
    end
  end

  def test_read_after_close_read_n_buffer
    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read(1, String.new) }
    end
  end

  def test_read_after_close_read_zero
    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read(0) }
    end
  end

  def test_read_after_close_read_zero_buffer
    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.read(0, String.new) }
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

  [1024, Bzip2::FFI::Reader.const_get(:READ_BUFFER_SIZE), Bzip2::FFI::Reader.const_get(:READ_BUFFER_SIZE) + 1, 8192].each do |size|
    define_method("test_bzip_truncated_to_#{size}_bytes") do
      partial = StringIO.new

      File.open(fixture_path('compressed.bz2'), 'rb') do |input|
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

    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
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

    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      suffixed.write(file.read)
    end

    suffixed.write('Test')

    suffixed.seek(0)

    Bzip2::FFI::Reader.open(suffixed) do |reader|
      assert_equal(65670, reader.read.bytesize)
      assert_equal(true, reader.eof?)
      assert_equal(true, reader.eof)
      assert_nil(reader.read(1))
      assert_equal(0, reader.read.bytesize)
    end

    assert_equal('Test', suffixed.read)
  end

  def test_data_after_compressed_no_seek
    suffixed = StringIO.new

    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      suffixed.write(file.read)
    end

    suffixed.write('Test')

    suffixed.seek(0)

    class << suffixed
      undef_method :seek
    end

    Bzip2::FFI::Reader.open(suffixed) do |reader|
      assert_equal(65670, reader.read.bytesize)
      assert_equal(true, reader.eof?)
      assert_equal(true, reader.eof)
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

    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      suffixed.write(file.read)
    end

    suffixed.write('Test')

    suffixed.seek(0)

    def suffixed.seek(amount, whence = IO::SEEK_SET)
      raise IOError, 'Cannot seek'
    end

    Bzip2::FFI::Reader.open(suffixed) do |reader|
      assert_equal(65670, reader.read.bytesize)
      assert_equal(true, reader.eof?)
      assert_equal(true, reader.eof)
      assert_nil(reader.read(1))
      assert_equal(0, reader.read.bytesize)
    end

    # For this input, the suffix will already have been consumed before the
    # end of the bzip2 stream is reached. There is no seek method, so it is not
    # possible to restore the position to the end of the bzip2 stream.
    assert_equal(0, suffixed.read.bytesize)
  end

  def test_data_after_compressed_multiple_structures
    suffixed = StringIO.new

    File.open(fixture_path('two_structures.bz2'), 'rb') do |file|
      suffixed.write(file.read)
    end

    suffixed.write('Test')

    suffixed.seek(0)

    Bzip2::FFI::Reader.open(suffixed) do |reader|
      assert_equal(111, reader.read.bytesize)
      assert_equal(true, reader.eof?)
      assert_equal(true, reader.eof)
      assert_nil(reader.read(1))
      assert_equal(0, reader.read.bytesize)
    end

    assert_equal('Test', suffixed.read)
  end

  def test_data_after_compressed_first_only
    File.open(fixture_path('two_structures.bz2'), 'rb') do |file|
      Bzip2::FFI::Reader.open(file, first_only: true) do |reader|
        assert_equal(55, reader.read.bytesize)
        assert_equal(true, reader.eof?)
        assert_equal(true, reader.eof)
        assert_nil(reader.read(1))
        assert_equal(0, reader.read.bytesize)
      end

      assert_equal('BZh', file.read(3)) # Bzip2 magic for second strcture
    end
  end

  def test_data_before_and_after_compressed
    # Tests that a relative seek (IO::SEEK_CUR) is performed to reset the
    # position.

    suffixed_and_prefixed = StringIOWithSeekCount.new
    suffixed_and_prefixed.write('Before')

    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      suffixed_and_prefixed.write(file.read)
    end

    suffixed_and_prefixed.write('After')

    suffixed_and_prefixed.seek(0)
    assert_equal('Before', suffixed_and_prefixed.read(6))

    Bzip2::FFI::Reader.open(suffixed_and_prefixed) do |reader|
      assert_equal(65670, reader.read.bytesize)
      assert_equal(true, reader.eof?)
      assert_equal(true, reader.eof)
      assert_nil(reader.read(1))
      assert_equal(0, reader.read.bytesize)
    end

    assert_equal(2, suffixed_and_prefixed.seek_count)
    assert_equal('After', suffixed_and_prefixed.read)
  end

  def test_data_before_and_after_compressed_first_only
    # Tests that a relative seek (IO::SEEK_CUR) is performed to reset the
    # position.

    prefixed = StringIOWithSeekCount.new
    prefixed.write('Before')

    File.open(fixture_path('two_structures.bz2'), 'rb') do |file|
      prefixed.write(file.read)
    end

    prefixed.seek(0)
    assert_equal('Before', prefixed.read(6))

    Bzip2::FFI::Reader.open(prefixed, first_only: true) do |reader|
      assert_equal(55, reader.read.bytesize)
      assert_equal(true, reader.eof?)
      assert_equal(true, reader.eof)
      assert_nil(reader.read(1))
      assert_equal(0, reader.read.bytesize)
    end

    assert_equal(2, prefixed.seek_count)
    assert_equal('BZh', prefixed.read(3)) # Bzip2 magic for second strcture
  end

  [[:eof, 'eof'], [:eof?, 'eof_q']].each do |(method, name)|
    define_method("test_sets_#{name}_when_complete") do
      Bzip2::FFI::Reader.open(fixture_path('compressed.bz2')) do |reader|
        assert_equal(false, reader.public_send(method))
        reader.read(17)
        assert_equal(false, reader.public_send(method))
        reader.read
        assert_equal(true, reader.public_send(method))
      end
    end

    define_method("test_#{name}_raises_io_error_when_closed") do
      File.open(fixture_path('compressed.bz2'), 'rb') do |file|
        reader = Bzip2::FFI::Reader.new(file)
        reader.close
        assert_raises(IOError) { reader.public_send(method) }
      end
    end
  end

  def test_pos_returns_decompressed_position
    Bzip2::FFI::Reader.open(fixture_path('compressed.bz2')) do |reader|
      assert_equal(0, reader.pos)
      reader.read(17)
      assert_equal(17, reader.pos)
      reader.read(8837)
      assert_equal(8854, reader.pos)
      reader.read
      assert_equal(65670, reader.pos)
    end
  end

  def test_pos_raises_io_error_when_closed
    File.open(fixture_path('compressed.bz2'), 'rb') do |file|
      reader = Bzip2::FFI::Reader.new(file)
      reader.close
      assert_raises(IOError) { reader.pos }
    end
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

  path_or_pathname_tests(:open_block) do |path_param|
    path = fixture_path('compressed.bz2')
    Bzip2::FFI::Reader.open(path_param.call(path)) do |reader|
      io = reader.send(:io)
      assert_kind_of(File, io)
      assert_equal(path.to_s, io.path)
      assert_raises(IOError) { io.write('test') }
      assert_nothing_raised { io.read(1) }
    end
  end

  path_or_pathname_tests(:open_no_block) do |path_param|
    path = fixture_path('compressed.bz2')
    reader = Bzip2::FFI::Reader.open(path_param.call(path))
    begin
      io = reader.send(:io)
      assert_kind_of(File, io)
      assert_equal(path, io.path)
      assert_raises(IOError) { io.write('test') }
      assert_nothing_raised { io.read(1) }
    ensure
      reader.close
    end
  end

  def test_open_block_path_always_autoclosed
    Bzip2::FFI::Reader.open(fixture_path('compressed.bz2'), autoclose: false) do |reader|
      assert_equal(true, reader.autoclose?)
    end
  end

  def test_open_no_block_path_always_autoclosed
    reader = Bzip2::FFI::Reader.open(fixture_path('compressed.bz2'), autoclose: false)
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
    assert_raises(RuntimeError) { Bzip2::FFI::Reader.open(fixture_path('compressed.bz2')) }
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

  path_or_pathname_tests(:class_read) do |path_param|
    class_read_test('test_path') do |compressed|
      Bzip2::FFI::Reader.read(path_param.call(compressed))
    end
  end

  def test_class_read_path_file_does_not_exist
    Dir.mktmpdir('bzip2-ffi-test') do |dir|
      assert_raises(Errno::ENOENT) { Bzip2::FFI::Reader.read(File.join(dir, 'test')) }
    end
  end
end
