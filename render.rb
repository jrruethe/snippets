#!/usr/bin/env ruby
require "json"

class String
  def render(parameters = {})
    self.scan(/\$\{.+?\}/).each do |m|
      k = m[2..-2]
      self.gsub!(m, parameters[k]) if parameters[k]
    end
    return self
  end
end

class Hash
  def render(parameters = {})
    JSON.parse(self.to_json.render(parameters))
  end
end
