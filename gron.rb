#!/usr/bin/env ruby

class Object
  def recursive_send(*args)
    args.inject(self){|obj, m| obj.send(m.shift, *m)}
  end
end

class String
  def is_i?
    !!self.match(/^(\d+)$/)
  end

  def cast
    return true  if self == "true"
    return false if self == "false"

    # This is pretty magical
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

class Integer
  def is_i?
    true
  end
end

class Array
  def map_to_hash
    h = {}
    self.each_with_index do |i, n|
      h[n] = i.respond_to?(:map_to_hash) ? i.map_to_hash : i
    end
    return h
  end
end

class Hash

  def self.autonew(*args)
    l = lambda{|h, k| h[k] = new(&l)}
    new(*args, &l)
  end

  def map_to_hash
    h = {}
    self.each do |key, value|
      h[key] = value.respond_to?(:map_to_hash) ? value.map_to_hash : value
    end
    return h
  end

  def each_path
    self.class.each_path(self){|path, object| yield path, object}
  end

  def gron
    h = {}
    self.map_to_hash.each_path do |path, value|
      h[path.gsub(/\.(\d+)/, '[\1]')] = value
    end
    return h
  end

  def to_array
    h = self.dup

    # Convert to an array if all the keys are integers
    h = h.values if h.keys.map(&:is_i?).all? && h.keys.map(&:to_i).min == 0

    case h
    when Hash
      h.each do |key, value|
        h[key] = value.is_a?(Hash) ? value.to_array : value
      end
    when Array
      h = h.map do |item|
        item.is_a?(Hash) ? item.to_array : item
      end
    end

    return h
  end

  def ungron
    h = Hash.autonew

    self.each do |key, value|
      key = key.gsub(/\[(\d+)\]/, ".\\1")
      tree = key.split(".").map{|x| [:[], x.is_i? ? x.to_i : x]}
      unless tree.empty?
        tree.push([:[]=, tree.pop[1], value])
        h.recursive_send(*tree)
      end
    end

    return h.to_array
  end

  protected

  def self.each_path(object, path = "", &block)
    if object.is_a?(Hash)
      object.each do |key, value|
        self.each_path(value, "#{path}#{path.empty? ? "" : "."}#{key}", &block)
      end
    else
      yield path, object
    end
  end

end

if $0 == __FILE__
  require "json"
  if ARGV.empty?
    puts "Usage: gron.rb file.json > file.txt"
    puts "       gron.rb -u file.txt > file.json"
    exit
  end

  if ARGV[0] == "-u"
    lines = File.readlines(ARGV[1]).map(&:chomp)
    hash = lines.map{|i| k,v = i.split("=", 2); [k, v.cast]}.to_h
    puts JSON.pretty_generate hash.ungron
  else
    json = JSON.parse File.read ARGV[0]
    require "pry"
    binding.pry
    json.gron.each do |k,v|
      puts "#{k}=#{v}"
    end
  end
end
