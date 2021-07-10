#!/usr/bin/env ruby
require "digest/sha2"

# Module for encoding and decoding in Base32 per RFC 3548
# https://github.com/stesla/base32/blob/master/lib/base32.rb
module Base32

  TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'.freeze
  @table = TABLE

  class <<self
    attr_reader :table
  end

  class Chunk
    def initialize(bytes)
      @bytes = bytes
    end

    def decode
      bytes = @bytes.take_while {|c| c != 61} # strip padding
      n = (bytes.length * 5.0 / 8.0).floor
      p = bytes.length < 8 ? 5 - (n * 8) % 5 : 0
      c = bytes.inject(0) do |m,o|
        i = Base32.table.index(o.chr)
        raise ArgumentError, "invalid character '#{o.chr}'" if i.nil?
        (m << 5) + i
      end >> p
      (0..n-1).to_a.reverse.collect {|i| ((c >> i * 8) & 0xff).chr}
    end

    def encode
      n = (@bytes.length * 8.0 / 5.0).ceil
      p = n < 8 ? 5 - (@bytes.length * 8) % 5 : 0
      c = @bytes.inject(0) {|m,o| (m << 8) + o} << p
      [(0..n-1).to_a.reverse.collect {|i| Base32.table[(c >> i * 5) & 0x1f].chr},
       ("=" * (8-n))]
    end
  end

  def self.chunks(str, size)
    result = []
    bytes = str.bytes
    while bytes.any? do
      result << Chunk.new(bytes.take(size))
      bytes = bytes.drop(size)
    end
    result
  end

  def self.encode(str)
    chunks(str, 5).collect(&:encode).flatten.join
  end

  def self.decode(str)
    chunks(str, 8).collect(&:decode).flatten.join
  end

end

class Checksum
  def self.generate(array)
    digest = Digest::SHA2.new(256)
    array.reject{|i| i.nil? || i.empty? || i.squeeze == " "}.each{|i| digest.update(i)}
    digest.hexdigest[0..1].upcase
  end

  def self.validate(array, checksum)
    c = self.generate(array)
    return c == checksum
  end
end

class String
  def correct_alphabet
    self.gsub("0", "O").gsub("1", "I")
  end
  def assume_hex
    self.gsub("O", "0").gsub("I", "1")
  end
end

class Printable

  def self.encode(data)

    # Get the data into base32
    base32 = Base32.encode(data)

    # Try to estimate a good length to use
    length = (Math.sqrt(base32.length) * 7 / 10).round
    length -= 1 if length % 2 != 0
    length = [length, 32].min

    # Split the string into segments of length x
    # length = 32
    groups = 2
    lines = base32.scan(/.{1,#{length*groups}}/)

    # Split each line into groups of y
    table = lines.map{|i| i.scan(/.{1,#{groups}}/)}

    # Normalize the table
    table.map!{|i| i.values_at(0..length-1).map{|j| j.nil? ? " " * groups : j}}

    # Generate the checksums
    row_checksums = table.map{|row| Checksum.generate(row)}
    col_checksums = table.transpose.map{|col| Checksum.generate(col)}
    final_checksum = (Checksum.generate(col_checksums).to_i(16) ^ Checksum.generate(row_checksums).to_i(16)).to_s(16).upcase
    col_checksums.push(final_checksum)

    # Append the checksums
    table = table.transpose
    table.push(row_checksums)
    table = table.transpose
    table.push(col_checksums)

    # Prepend a line number to each line
    lines = table.length
    width = lines.to_s.length
    prefix = [width, groups].max
    table = table.each_with_index.map{|i, n| i.unshift(n == table.length-1 ? "X" * prefix : (n+1).to_s.rjust(prefix, "0")); i}

    # Add column counts
    space = "#" * prefix
    table.unshift([space] + 1.upto(length).map{|i| i.to_s.rjust(groups, "0")} + ["X" * groups])

    # Format to a string
    return table.map{|row| row.join(" ")}.join("\n")
  end

  def self.decode(input)

    # Split the input into lines
    lines = input.split("\n")

    # The second-to-last line might be truncated
    # Fill in the spaces with dashes
    lines[-2] = lines[-2].gsub("   ", "|--").gsub("|", " ")

    # Convert to a table
    table = lines.map{|i| i.split(" ")}
    table[-2] = table[-2].map{|i| i == "--" ? "  " : i}

    # Remove the line numbers
    table.shift
    table.map!{|i| i.shift; i}

    # Extract the checksums
    row_checksums = table[0..-2].map{|i| i[-1].assume_hex}
    col_checksums = table[-1][0..-2].map{|i| i.assume_hex}
    final_checksum = table[-1][-1].assume_hex

    # Validate the checksums
    row_valid = table[0..-2].each_with_index.map{|i, n| Checksum.generate(i[0..-2].map{|j| j.correct_alphabet}) == row_checksums[n]}
    col_valid = table.transpose[0..-2].each_with_index.map{|i, n| Checksum.generate(i[0..-2].map{|j| j.correct_alphabet}) == col_checksums[n]}
    final_valid = (Checksum.generate(col_checksums).to_i(16) ^ Checksum.generate(row_checksums).to_i(16)).to_s(16).upcase == final_checksum

    # TODO
    # Cases to handle
    # All rows valid, but columns have failures
    # All cols valid, but rows have failures
    # All rows and cols valid, but final checksum fails

    unless final_valid
      STDERR.puts "Error found in checksum, double-check the last row and last column."
      return false
    end

    failed_rows = row_valid.each_with_index.select{|i,n| i == false}.map{|i| i.last}
    failed_cols = col_valid.each_with_index.select{|i,n| i == false}.map{|i| i.last}

    fail = false
    failed_rows.each do |r|
      failed_cols.each do |c|
        STDERR.puts "Error found: row #{r}, column #{c}"
        fail = true
      end
    end
    return false if fail

    # Data is valid, decode
    data = table[0..-2].map{|i| i[0..-2].join("")}.join("").gsub(" ", "").correct_alphabet
    return Base32.decode(data)
  end

end

# string = "this is the song that never ends, this song goes on and on my friends"
# output = Printable.encode(string)
# puts output
# File.open("output.txt", "w"){|f| f.puts(output)}
# puts ""
# puts Printable.decode(output)
# puts Printable.decode(File.read("output.txt"))

if $0 == __FILE__

  def usage
    puts "Usage: printable.rb -e <FILE>"
    puts "       printable.rb -d <FILE>"
    exit 0
  end

  usage unless ARGV.size == 2

  case ARGV[0]
  when "-e"
    puts Printable.encode(File.read(ARGV[1]))
  when "-d"
    puts Printable.decode(File.read(ARGV[1]))
  else
    usage
  end
end
