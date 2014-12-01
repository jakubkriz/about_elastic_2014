#encoding:utf-8

# require lib dir
lib_dir = File.expand_path("../lib", __FILE__)
$: << lib_dir unless $:.include?(lib_dir)

# require config dir
config_dir = File.expand_path("../config", __FILE__)
$: << config_dir unless $:.include?(config_dir)
require './lib/app'
require './config/config'

use Rack::MethodOverride

run BooksSearch
