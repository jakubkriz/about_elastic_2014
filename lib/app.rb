#encoding: utf-8
require 'sequel'
require 'sinatra'
require 'slim'
require './config/database'
require_relative './helpers/facebook'


class FacebookStats < Sinatra::Base

  include Facebook

  set :views, './views'
  set :public_folder, './public'

  helpers do

    def refresh_link(link_id, url)
      rslt = Facebook.download url
      return false if rslt.key?('error')
      DB[:Stats].insert(
        :link_id       => link_id,
        :likes_count   => rslt['like_count'],
        :shares_count  => rslt['share_count'],
        :download_time => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
      )
    end

  end

  before do
    @author, @year = 'Tomas', Time.now.year
  end

  not_found do
    'Tady nemáš co dělat!'
  end

  # refresh
  get '/refresh' do
    links = DB[:Links].all
    links.each { |link|
      refresh_link link[:id], link[:url]
    }
    redirect to('/')
  end

  # link detail
  get '/link/:id' do
    @url   = DB[:Links].where(:id => params[:id]).first
    @stats = DB[:Stats].where(:link_id => params[:id]).reverse_order(:download_time)
    slim :stats, :layout => true
  end

  # list of URLs
  get '/' do
    @links = DB[:Links].left_join(:Stats, :Stats__link_id => :Links__id).
      reverse_order(:download_time).group_by(:Links__id).select{
        [
          :Links__id___id, :domain, :url, :facebook_id, :facebook_likes,
          :likes_count, :shares_count, :Stats__id___stat_id
        ]
    }
    slim :links, :layout => true
  end

  # ADD LINK
  post '/links' do
    base_domain = Facebook.get_domain params['url']
    redirect to('/') unless base_domain
    info        = Facebook.download_domain base_domain
    url         = Facebook.clean_url params['url']
    id = DB[:Links].insert(
      :url            => url,
      :domain         => base_domain,
      :facebook_id    => info[:id],
      :facebook_likes => info[:likes]
    )
    refresh_link id, url
    redirect to('/')
  end

  # REMOVE LINK
  delete '/link/:id' do
    DB[:Stats].where(:link_id => params[:id]).delete
    DB[:Links].where(:id => params[:id]).delete
    redirect to('/')
  end

  # UPDATE LINK
  put '/link/:id' do
    # DB[:Links].where(:id => params[:id]).update(.....)
    redirect to('/')
  end

  # get link edit form
  get '/link/:id/edit' do
    @link = DB[:Links].where(:id => params[:id]).first
    slim :link_form, :layout => true
  end

  # GET FORM FOR UPDATE LINK

  # ----------------------------

end
