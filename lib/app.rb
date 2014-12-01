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
    @book = @elastic.get_doc params['sysno']
    slim :detail, :layout => true
  end

  post '/search' do
    if params.include?('search')
      if params['search'].match(/\A[\s\d,]+\z/)
        books  =
          @elastic.get_docs params['search'].split(',').map { |id| id.strip }
        @books = books.values
      else
        query =
          { "query" => {
              "bool" => {
              }
            }
          }
        if !params.include?('author') && params.include?('title')
          query['query']['bool']['must'] =
          { "text" => {"search_title" => params['search']}}
        elsif !params.include?('title') && params.include?('author')
          query['query']['bool']['must'] =
          { "text" => {"author.search_name" => params['search']}}
        else
          query['query']['bool']['should'] = [
            { "text" => {"search_title" => params['search']}},
            { "text" => {"search_name"  => params['search']}}
          ]
        end
        books = @elastic.search query
        @books = books.values
      end
    end
    @books ||= []

    slim :index, :layout => true
  end

end
