#!/usr/bin/env ruby

class String
  def is_i?
    !!self.match(/^(\d+)$/)
  end
end
