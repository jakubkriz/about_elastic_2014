# encoding: UTF-8
require 'sqlite3'
require 'sequel'
require 'yaml'

ENV["RACK_ENV"] ||= "development"
database_config = YAML::load(File.read("config/database.yml"))
DB = Sequel.connect(database_config[ENV["RACK_ENV"]])