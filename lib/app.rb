#encoding: utf-8
require 'sequel'
require 'sinatra'
require 'slim'
require_relative './helpers/facebook'


class FacebookStats < Sinatra::Base

  include Facebook
  DB = Sequel.sqlite

  set :views, './views'
  set :public_folder, './public'

  before do
    @author, @year = 'Tomas', Time.now.year
  end

  not_found do
    'Tady nemáš co dělat!'
  end

  get '/' do
    'BAF'
  end

  # ADD LINK

  # REMOVE LINK

  # UPDATE LINK

  # GET FORM FOR UPDATE LINK

  # ----------------------------

end
