require 'rubygems'


# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

#require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])

# hack na obchod buildin vs bunderovany 'net/protocol'
require 'net/protocol'
