require 'ffi'

module Locale
  extend FFI::Library
  ffi_lib FFI::Library::LIBC

  # Define strcoll function for locale-sensitive comparison
  attach_function :strcoll, [:string, :string], :int
  attach_function :setlocale, [:int, :string], :string

  LC_ALL = 6  # Locale category constant

  # Set locale to Czech
  setlocale(LC_ALL, "cs_CZ.UTF-8")
end

