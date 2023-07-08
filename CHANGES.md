# Changes

## Version 1.1.1 - 8-Jul-2023

* Added `Bzip2::FFI::Reader#tell`, returning the number of decompressed bytes
  that have been read. `Bzip2::FFI::Reader#pos` is now an alias for
  `Bzip2::FFI::Reader#tell`.
* Added `Bzip2::FFI::Writer#tell`, returning the number of uncompressed bytes
  that have been written. `Bzip2::FFI::Writer#pos` is now an alias for
  `Bzip2::FFI::Writer#tell`.


## Version 1.1.0 - 27-Feb-2021

* `Bzip2::FFI::Reader` will now read all consecutive bzip2 compressed structures
  in the input by default instead of just the first (the same as the
  bzip2/bunzip2 commands). A new `:first_only` option has been added to allow
  the version 1.0.0 behaviour to be retained. #1.
* Added `#eof?` and `#eof` to `Bzip2::FFI::Reader`, indicating when
  decompression has completed.
* Added `Bzip2::FFI::Reader#pos`, returning the number of decompressed bytes
  that have been read.
* Added `Bzip2::FFI::Writer#pos`, returning the number of uncompressed bytes
  that have been written.
* Support using Bzip2::FFI with frozen string literals enabled (and enable in
  all files with `# frozen_string_literal: true`).
* Constants documented as private in version 1.0.0 are now set as private using
  `Module#private_constant`.
* `require_relative` is now used when loading dependencies for a minor
  performance gain.


## Version 1.0.0 - 28-Feb-2015

* First release.
