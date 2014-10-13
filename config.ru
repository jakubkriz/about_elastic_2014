#encoding:utf-8

# require lib dir
lib_dir = File.expand_path("../lib", __FILE__)
$: << lib_dir unless $:.include?(lib_dir)
require './lib/app'

run FacebookStats