#!/usr/bin/env ruby

class Hash
  def reorder_keys(array)
    array.map{|k| [k, self[k]]}.to_h
  end
end
