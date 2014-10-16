#!/usr/bin/env ruby
#encoding:utf-8
require 'net/http'
require 'json'
require 'uri'
require 'pp'

module Facebook

  FACEBOOK_GRAPH_URL = 'http://graph.facebook.com/'
  FACEBOOK_API_URL   = 'http://api.facebook.com/'
  UNKNOWN            = 'neznámý'

  class << self

    def get_domain(url)
      base_domain = URI.parse(url).host
      return nil unless base_domain
      base_domain.downcase =~ /(?:.*\.)?(\S+\.[a-z]{1,4})\z/ ? $1 : nil
    end

    def send_request(base_url, tail='')
      url      = URI.join base_url, tail
      response = Net::HTTP.get_response url
      unless response.code == '200'
        pp "DOWNLOAD error for '#{url}': #{response.code} #{response.body}"
        return {}
      end
      JSON.parse response.body
    end

    def download_domain base_domain
      response_domain = self.send_request FACEBOOK_GRAPH_URL, "#{base_domain}?format=json"
      {
        :id    => response_domain['id']    || UNKNOWN,
        :likes => response_domain['likes'] || UNKNOWN,
      }
    end

    def download url
      response_url = self.send_request(
        FACEBOOK_API_URL, "method/links.getStats?urls=#{URI::encode(url)}&format=json")
      response_url.kind_of?(Array) ? response_url.first : response_url
    end

    def clean_url url
      url.sub(/#\S+\z/, '')
    end

  end

end
