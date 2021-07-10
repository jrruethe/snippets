#!/usr/bin/env ruby

class String
  def snake_case
    self.downcase.gsub(/[^a-zA-Z0-9]/, "_").squeeze("_")
  end
end

if $0 == __FILE__
  # Run some tests
  {
    "Hello World" => "hello_world",
    "CAPS" => "caps",
    "EC2" => "ec2",
    "H[]w @r3 y()u?" => "h_w_r3_y_u_"
  }
  .each do |k,t|
    v = k.snake_case
    puts "#{v==t ? "PASS" : "*FAIL*"}: #{k} => #{v}"
  end
end
