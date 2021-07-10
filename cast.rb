#!/usr/bin/env ruby

class String
  def cast
    return true  if self == "true"
    return false if self == "false"
    
    [
      :Integer,
      :Float
    ].each do |i|
      begin
        return Kernel.send(i, self)
      rescue
        next
      end
    end

    return self
  end
end
