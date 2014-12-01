# encoding:utf-8

class Time

  def to_es_time
    self.getutc.iso8601
  end

end
