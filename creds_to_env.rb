#!/usr/bin/env ruby

# Use like this at the top of a bash script
# # Load the credentials
# export AWS_PROFILE=nonprod
# . <(./creds_to_env.rb ${AWS_PROFILE})

abort "Usage: creds_to_env.rb <PROFILE>" if ARGV.empty?
profile = ARGV[0]

# Read the credentials
credentials = File.readlines("#{ENV["HOME"]}/.aws/credentials").map(&:chomp)

# Find the section indices
indices = credentials.each_with_index.select{|i,n| i =~ /\[.+\]/}.map(&:last)

# Convert to section spans
spans = indices.zip(indices[1..-1]+[-1]).map{|i,j| [i, j>1?j-1:j]}

# Map sections to a usable hash
parsed = spans.map do |i,j|
  lines = credentials[i..j].reject(&:empty?)
  key = lines.first[1..-2]
  value = lines[1..-1].map{|x| _, k, v = *x.match(/^(.+?)=(.+)$/); [k.upcase, v]}.to_h
  [key, value]
end.to_h

# Output the credentials in bash format
puts %{export AWS_PROFILE=#{profile}}
parsed[profile].each{|k,v| puts %{export #{k}="#{v}"}.squeeze("\"")}
