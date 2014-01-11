# set default locale to something other than :en
require 'ffi-locale'

I18n.default_locale = :cs
FFILocale::setlocale FFILocale::LC_COLLATE, 'cs_CZ.UTF8'

