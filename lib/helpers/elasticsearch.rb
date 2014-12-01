#encoding:utf-8
require 'bundler/setup'
require 'glogg'
require 'curburger'
require 'oj'

require 'helpers/util'

class ElasticSearch

  Oj.default_options = {mode: :compat}

  attr_accessor :idx, :idx_node, :idx_mentions

  # idx - index name OR index type
  # opts - optional configuration:
  #   :url - database url (default localhost)
  #   :ua  - Curburger::Client instance options
  def initialize(idx, opts = {})
    opts[:direct_idx] = false unless opts.include?(:direct_idx)

    @url = opts[:url] || $ES[:url] || 'http://127.0.0.1:9200'
    @idx = $ES.include?(idx.to_sym) ? $ES[idx.to_sym] : idx

    GLogg.ini(File.expand_path("../../log/elastic.log", File.dirname(__FILE__)), GLogg::L_D4)

    @ua_opts = (opts[:ua] || $ES[:ua] || {}).merge({
      :ignore_kill  => true,
      :req_norecode => true,
    })
    @ua = Curburger.new @ua_opts
  end

  # alias method for getting node document (page, user, group...)
  def get_node(id, idx = @idx_node, type = 'document')
    get_docs(id, idx, type)
  end

  # alias method for saving node document (page, user, group...)
  def save_node(node, idx = @idx_node, type = 'document')
    save_docs(node, idx, type)
  end

  # alias method for getting mentions
  def get_mentions(ids, idx = @idx_mentions, type = 'document')
    get_docs(ids, idx, type)
  end

  # alias method for saving mentions
  def save_mentions(mentions, idx = @idx_mentions, type = 'document')
    save_docs(mentions, idx, type)
  end

  def get_document(key, idx = @idx, type = 'document')
    response = get_doc(key, idx, type) or return nil
    response.values.first
  end

  # ids - single id or array of ids
  # return nil in case of error, {id => doc} of documents found otherwise
  def get_docs(ids, idx = @idx, type = 'document')
    return {} unless ids
    ids = [ids] unless ids.kind_of?(Array)
    return {} if ids.empty?

    url, docs  = "#{@url}/#{idx}/_search", {}
    self.class.array_slice_indexes(ids).each { |slice|
      data = {'filter' => {'ids' => {'type' => type, 'values' => [*slice]}}}
      response  = request_elastic(
        :post,
        url,
        Oj.dump(data),
      ) or return nil

      response['hits']['hits'].each { |doc|
        docs[doc['_id']] = doc['_source']
      }
    }
    docs
  end # get_docs

  def get_doc(key, idx = @idx, type = 'document', attempts = 1)
    response = request_elastic(:get, "#{@url}/#{idx}/#{type}/#{key}")
    return nil unless response && response.kind_of?(Hash) &&
      response.include?('exists') && response['exists']
    {response['_id'] => response['_source']}
  end # save_docs

  # docs - [docs] or {id => doc}
  def save_docs(docs, idx = @idx, type = 'document')
    return true unless docs && !docs.empty? # nothing to save
    to_save = []
    if docs.kind_of?(Hash) # convert to array
      if docs.include?('id')
        to_save << docs
      else
        docs.each_pair { |id, doc| to_save.push(doc.merge({'id' => id})) }
      end
    elsif docs.kind_of? Array
      to_save = docs
    else # failsafe
      raise "Incorrect docs supplied (#{docs.class})"
    end

    # saving single document via direct POST request
    if to_save.count == 1

      GLogg.l_f{ " ES PAGE save alone : #{to_save.first}" }

      response = request_elastic(
        :post,
        "#{@url}/#{idx}/#{type}/#{to_save.first['id']}",
        Oj.dump(to_save.first),
        {:content_type => 'application/json'}
      )
      return response
    end

    # more than 1 docoument save via BULK
    self.class.array_slice_indexes(to_save).each { |slice|
      bulk = ''
      slice.each { |doc|
        bulk += %Q({"index": {"_index": "#{idx}", "_id": "#{doc['id']}", "_type": "#{type}"}}\n)
        bulk += Oj.dump(doc) + "\n"
      }
      return nil if bulk.empty? # should not happen
      bulk    += "\n" # empty line in the end required
      request_elastic(:post, "#{@url}/_bulk", bulk)
    }
    true
  end # save_docs

  # query - hash of the query to be done
  # return nil in case of error, rsp['hits'] otherwise
  def search(query, idx = @idx)
    url, data = "#{@url}/#{idx}/_search", Oj.dump(query)
    response  = request_elastic(:post, url, data) or return nil
    docs = {}
    response['hits']['hits'].each { |doc|
      docs[doc['_id']] = doc['_source']
    }
    docs
  end # count

  # query - hash of the query to be done
  # return nil in case of error, document count otherwise
  def count(query, idx = @idx)
    url  = "#{@url}/#{idx}/_count"

    rsp = request_elastic(:get, url, query) or return 0
    rsp['count'].to_i
  end # count

  # query - direct GET query through URL
  # return nil in case of error, documents (unprepared) otherwise
  def direct_query(idx, query, what = '_search')
    url = "#{@url}/#{idx}/#{what}?#{query}"
    request_elastic :get, url
  end # direct_query

  # query - hash of the query to be done
  # opts can override scroll validity, size, etc.
  # return nil in case of error, otherwise scroll hash
  # {:scroll => <scroll_param>, :scroll_id => <scroll_id>, :total => total}
  def scan(query, idx, opts = {})
    o = {'scroll' => '10m', 'size' => 200}.merge Util.hash_keys_to_str opts
    url = "#{@url}/#{idx}/_search?search_type=scan&#{Util.param_str o}"
    data = Oj.dump query

    rsp = request_elastic(:post, url, data) or return false

    {
      :scroll    => o['scroll'],
      :scroll_id => rsp['_scroll_id'],
      :total     => rsp['hits']['total'].to_i
    }
  end # scan

  # wrapper to scroll each document for the initialized scan
  # scan - hash as returned by scan method above
  # each document is yielded for processing
  # return nil in case of error (any of the requests failed),
  # count of documents scrolled otherwise
  def scroll_each scan
    count, total = 0, nil
    while true
      url = "#{@url}/_search/scroll?scroll=#{CGI.escape scan[:scroll]}&" +
        "scroll_id=#{CGI.escape scan[:scroll_id]}"

      rsp = request_elastic(:get, url)

      unless rsp
        GLogg.l_f { 'ElasticSearch.scroll_each: FAILED SCROLL' }
        return count
      end

      scan[:scroll_id] = rsp['_scroll_id']
      total ||= rsp['hits']['total'].to_i

      rsp['hits']['hits'].each { |document|
        yield document
        count += 1
      }
      break if rsp['hits']['hits'].empty?
    end
    count
  end # scroll_each

  private

  def request_elastic(method, url, data = nil, params = {})
    req_params = []
    params.merge!({:content_type => 'application/json'}) unless
      params.include?(:content_type)
    req_params.push(method, url)
    # hack for ES and Count with query
    if method == :get  && data && !data.empty?
      params.merge!({:data => data}) unless params.include?(:data)
      l_data = data.dup
      data = nil
    end
    req_params << data   if data && !data.empty?
    req_params << params if params && !params.empty?

    response = nil
    response = attempt_elastic req_params


    unless response && !response[:error]
      GLogg.l_f { "ElasticSearch.request_elastic: Failed #{method} #{url}\n #{data}\n " +
        " Last error: '#{response[:error] if response && response.kind_of?(Hash)}'\n" +
        " Response:\n '#{response[:content] if response && response.kind_of?(Hash)}'"
      }
      return false
    end

    GLogg.l_d4 {
      "ATTEMPT ELASTIC WITH method: '#{method.to_s.upcase}' " +
      "with url '#{url}' \n" +
      "#{data}"
    }
    begin
      return Oj.load(response[:content])
    rescue SyntaxError, Oj::ParseError => e
      GLogg.l_e { "ElasticSearch.request_elastic: Oj.load failed "}
    end
    return false
  end

  def attempt_elastic params
    $ES[:attempts].times { |attempt|
      begin
        @ua.reset # ensure reset because of bug in Curb ? #TODO
        rsp = @ua.send(*params)
        return rsp
      rescue => e
        GLogg.l_w { "ElasticSearch.attempt_elastic: #{params} : '#{e.message}' \n #{e.backtrace.inspect}" }
        # sleep $ES[:sleep]
        next
      end
    }
    return false
  end

  SLICES = 1000

  # prepare array indexes,lengths in the manner of slices
  # e.g. for a.length=25 and cnt=10 return [[0,10],[10,10],[20,5]]
  def self.array_slice_indexes(ids, cnt = SLICES)
    ids  = ids.dup
    rslt = []
    rslt << ids.shift(cnt) until ids.empty?
    rslt
  end

end # ElasticSearch

