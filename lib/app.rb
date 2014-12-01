#encoding: utf-8
require 'sinatra'
require 'slim'
require 'helpers/elasticsearch'

class BooksSearch < Sinatra::Base

  set :views, './views'
  set :public_folder, './public'

  before do
    @elastic = ElasticSearch.new $ES[:idx], {:direct_idx => true}
  end

  get '/' do
    slim :index, :layout => true
  end

  # book detail
  get '/book/:sysno' do
    # method: get_doc
    slim :detail, :layout => true
  end

  post '/search' do
    # sysno ?
    #   method: get_docs
    #   split sysno text with ; as Array
    #
    # text ?
    #   method: search
    #   search in search_title AND author.search_name with should
    # text and missing checkbox?
    #   method: search
    #   search with must in specific key
    slim :index, :layout => true
  end

end
