#encoding:utf-8
require 'cgi'

module Util

  # convert all keys in the hash to string
  def self.hash_keys_to_str h
    new_h = {}
    h.each_pair { |k, v| new_h[k.to_s] = h[k] }
    new_h
  end

  # assemble additional parameter string from options in hash
  # e.g. {'arg1' => 'val1', 'arg2' => 'val2'} => 'arg1=val1&arg2=val2'
  def self.param_str h, join='&'
    arr = []
    h.each_pair{|p,arg| arr.push "#{CGI.escape p.to_s}=#{CGI.escape arg.to_s}" }
    arr.join join
  end

  def self.tmlen l, msec=false
    t = []
    t.push l/86400; l %= 86400
    t.push l/3600;  l %= 3600
    t.push l/60;    l %= 60
    t.push l
    out = sprintf '%u', t.shift
    out = out == '0' ? '' : out + ' days, '
    out += sprintf(msec ? '%u:%02u:%06.3f' : '%u:%02u:%02u', *t)
  end

end # Util
