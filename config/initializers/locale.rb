# set default locale to something other than :en
require 'ffi-locale'

I18n.default_locale = :cs
FFILocale::setlocale FFILocale::LC_ALL, 'cs_CZ.UTF-8'

