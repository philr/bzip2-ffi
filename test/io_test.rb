require 'test_helper'

class IOTest < Minitest::Test
  class DummyIO
    def initialize
      @closed = false
    end
    
    def close
      @closed = true
    end

    def closed?
      @closed
    end
  end

  class NoCloseIO
  end

  class TestIO < Bzip2::FFI::IO
    class << self
      public :new
      public :open
    end

    public :io
    public :stream
    public :check_closed
    public :check_error

    def initialize(io, options = {})
      super

      raise 'test' if options[:test_initialize_raise_exception]
    end
  end

  def test_autoclose_set_true
    io = TestIO.new(DummyIO.new, autoclose: false)
    assert_equal(false, io.autoclose?)
    io.autoclose = true
    assert_equal(true, io.autoclose?)
  end

  def test_autoclose_set_truthy
    io = TestIO.new(DummyIO.new, autoclose: false)
    assert_equal(false, io.autoclose?)
    io.autoclose = 'false'
    assert_equal(true, io.autoclose?)
  end

  def test_autoclose_set_false
    io = TestIO.new(DummyIO.new, autoclose: true)
    assert_equal(true, io.autoclose?)
    io.autoclose = false
    assert_equal(false, io.autoclose?)
  end

  def test_autoclose_set_not_truthy
    io = TestIO.new(DummyIO.new, autoclose: true)
    assert_equal(true, io.autoclose?)
    io.autoclose = nil
    assert_equal(false, io.autoclose?)
  end

  def test_autoclose_get_when_closed
    io = TestIO.new(DummyIO.new)
    io.close
    assert_raises(IOError) { io.autoclose? }
  end

  def test_autoclose_set_when_closed
    io = TestIO.new(DummyIO.new)
    io.close
    assert_raises(IOError) { io.autoclose = true }
  end

  def test_binmode?
    io = TestIO.new(DummyIO.new)
    assert_equal(true, io.binmode?)
  end

  def test_binmode_get_when_closed
    io = TestIO.new(DummyIO.new)
    io.close
    assert_raises(IOError) { io.binmode? }
  end

  def test_binmode
    io = TestIO.new(DummyIO.new)
    assert_same(io, io.binmode)
    assert_equal(true, io.binmode?)
  end

  def test_binmode_set_when_closed
    io = TestIO.new(DummyIO.new)
    io.close
    assert_raises(IOError) { io.binmode }
  end

  def test_close_without_autoclose
    dummy_io = DummyIO.new
    io = TestIO.new(dummy_io)
    refute(dummy_io.closed?)
    io.close
    refute(dummy_io.closed?)
  end

  def test_close_with_autoclose
    dummy_io = DummyIO.new
    io = TestIO.new(dummy_io, autoclose: true)
    refute(dummy_io.closed?)
    io.close
    assert(dummy_io.closed?)
  end

  def test_close_with_unclosable_and_autoclose
    no_close_io = NoCloseIO.new
    io = TestIO.new(no_close_io, autoclose: true)
    assert_nothing_raised { io.close }
  end

  def test_close_returns_nil
    io = TestIO.new(DummyIO.new)
    assert_nil(io.close)
  end

  def test_close_when_closed
    io = TestIO.new(DummyIO.new)
    io.close
    assert_raises(IOError) { io.close }
  end

  def test_closed
    io = TestIO.new(DummyIO.new)
    assert_equal(false, io.closed?)
    io.close
    assert_equal(true, io.closed?)
  end
  
  def test_external_encoding
    io = TestIO.new(DummyIO.new)
    assert_equal(Encoding::ASCII_8BIT, io.external_encoding)
  end

  def test_external_encoding_when_closed
    io = TestIO.new(DummyIO.new)
    io.close
    assert_raises(IOError) { io.external_encoding }
  end

  def test_internal_encoding
    io = TestIO.new(DummyIO.new)
    assert_equal(Encoding::ASCII_8BIT, io.internal_encoding)
  end

  def test_internal_encoding_when_closed
    io = TestIO.new(DummyIO.new)
    io.close
    assert_raises(IOError) { io.internal_encoding }
  end

  def test_io
    dummy_io = DummyIO.new
    io = TestIO.new(dummy_io)
    assert_same(dummy_io, io.io)
  end

  def test_initialize_nil_io
    assert_raises(ArgumentError) { TestIO.new }
  end

  def test_initialize_calls_binmode_on_io
    dummy_io = Minitest::Mock.new
    dummy_io.expect(:binmode, dummy_io)
    TestIO.new(dummy_io)
    assert(dummy_io.verify)
  end

  def test_initialize_autoclose_default
    io = TestIO.new(DummyIO.new)
    assert_equal(false, io.autoclose?)
  end

  def test_initialize_autoclose_option
    io = TestIO.new(DummyIO.new, autoclose: true)
    assert_equal(true, io.autoclose?)
  end

  def test_stream
    io = TestIO.new(DummyIO.new)
    s = io.stream
    refute_nil(s)
    assert_kind_of(Bzip2::FFI::Libbz2::BzStream, s)
  end

  def test_stream_when_closed
    io = TestIO.new(DummyIO.new)
    io.close
    assert_raises(IOError) { io.stream }
  end

  def test_check_closed_when_open
    io = TestIO.new(DummyIO.new)
    assert_nothing_raised { io.check_closed }
  end

  def test_check_closed_when_closed
    io = TestIO.new(DummyIO.new)
    io.close
    e = assert_raises(IOError) { io.check_closed }
    assert_equal('closed stream', e.message)
  end

  def test_check_error_not_error
    io = TestIO.new(DummyIO.new)
    
    (0..4).each do |i|
      assert_equal(i, io.check_error(i))
    end
  end

  def test_check_error_error
    codes = {
      Bzip2::FFI::Libbz2::BZ_SEQUENCE_ERROR => Bzip2::FFI::Error::SequenceError,
      Bzip2::FFI::Libbz2::BZ_PARAM_ERROR => Bzip2::FFI::Error::ParamError,
      Bzip2::FFI::Libbz2::BZ_MEM_ERROR => Bzip2::FFI::Error::MemoryError,
      Bzip2::FFI::Libbz2::BZ_DATA_ERROR => Bzip2::FFI::Error::DataError,
      Bzip2::FFI::Libbz2::BZ_DATA_ERROR_MAGIC => Bzip2::FFI::Error::MagicDataError,
      Bzip2::FFI::Libbz2::BZ_CONFIG_ERROR => Bzip2::FFI::Error::ConfigError
    }

    io = TestIO.new(DummyIO.new)

    codes.each do |code, error_class|
      assert_raises(error_class) { io.check_error(code) }
    end
  end

  def test_check_error_unexpected
    io = TestIO.new(DummyIO.new)

    # -6, -7 and -8 are codes that are only raised by the libbz2 high-level
    # interface. Only the low-level interface is used by Bzip2::FFI.
    # -10 is not defined by libbz2.
    [-6, -7, -8, -10].each do |code|
      error = assert_raises(Bzip2::FFI::Error::UnexpectedError) { io.check_error(code) }
      assert_includes(error.message, code.to_s)
    end
  end

  def test_open_no_block
    dummy_io = DummyIO.new
    io = TestIO.open(dummy_io)
    assert_kind_of(TestIO, io)
    refute(io.closed?)
    assert_equal(false, io.autoclose?)
    assert_same(dummy_io, io.io)
  end

  def test_open_no_block_options
    dummy_io = DummyIO.new
    io = TestIO.open(dummy_io, autoclose: true)
    assert_kind_of(TestIO, io)
    refute(io.closed?)
    assert_equal(true, io.autoclose?)
    assert_same(dummy_io, io.io)
  end

  def test_open_no_block_proc
    dummy_io = nil
    io = TestIO.open(-> { dummy_io = DummyIO.new })
    refute_nil(dummy_io)
    assert_same(dummy_io, io.io)
    refute(dummy_io.closed?)
  end

  def test_open_no_block_proc_closed_on_exception
    dummy_io = nil

    assert_raises(RuntimeError) do
      TestIO.open(-> { dummy_io = DummyIO.new }, test_initialize_raise_exception: true)
    end

    refute_nil(dummy_io)
    assert(dummy_io.closed?)
  end

  def test_open_no_block_proc_closed_on_exception_unless_no_close
    no_close_io = nil

    assert_raises(RuntimeError) do
      TestIO.open(-> { no_close_io = NoCloseIO.new }, test_initialize_raise_exception: true)
    end

    refute_nil(no_close_io)
  end

  def test_open_block
    dummy_io = DummyIO.new
    copy_io = nil

    res = TestIO.open(dummy_io) do |io|
      assert_kind_of(TestIO, io)
      refute(io.closed?)
      assert_equal(false, io.autoclose?) 
      assert_same(dummy_io, io.io)
      copy_io = io
      42
    end

    assert(copy_io.closed?)
    assert_equal(42, res)    
  end

  def test_open_block_options
    dummy_io = DummyIO.new
    copy_io = nil

    res = TestIO.open(dummy_io, autoclose: true) do |io|
      assert_kind_of(TestIO, io)
      refute(io.closed?)
      assert_equal(true, io.autoclose?) 
      assert_same(dummy_io, io.io)
      copy_io = io
      42
    end

    assert(copy_io.closed?)
    assert_equal(42, res) 
  end

  def test_open_block_closes
    # Shouldn't raise an exception if the block closes the io.
    res = TestIO.open(DummyIO.new) do |io|
      io.close
      :block_closed
    end

    assert_equal(:block_closed, res)
  end

  def test_open_block_proc
    dummy_io = nil

    TestIO.open(-> { dummy_io = DummyIO.new }) do |io|
      refute_nil(dummy_io)
      assert_same(dummy_io, io.io)
      refute(dummy_io.closed?)
    end
  end

  def test_open_block_proc_closed_on_exception
    dummy_io = nil

    assert_raises(RuntimeError) do
      TestIO.open(-> { dummy_io = DummyIO.new }, test_initialize_raise_exception: true) do |io|
        flunk('block should not be called')
      end
    end

    refute_nil(dummy_io)
    assert(dummy_io.closed?)
  end

  def test_open_block_proc_closed_on_exception_unless_no_close
    no_close_io = nil

    assert_raises(RuntimeError) do
      TestIO.open(-> { no_close_io = NoCloseIO.new }, test_initialize_raise_exception: true) do |io|
        flunk('block should not be called')
      end
    end

    refute_nil(no_close_io)
  end

  def test_open_io_nil
    assert_raises(ArgumentError) { TestIO.open(nil) }
  end
end
