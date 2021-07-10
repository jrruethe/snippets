#!/usr/bin/env ruby

require "erb"
require "ostruct"

class Namespace
  def initialize(hash)
    hash.each do |k,v|
      singleton_class.send(:define_method, k.to_sym){v}
    end
  end

  def get_binding
    binding
  end
end

class String
  def render(parameters = {})
    ERB.new(self, nil, "-").result(Namespace.new(parameters).get_binding)
  end
end
