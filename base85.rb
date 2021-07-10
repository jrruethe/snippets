#!/usr/bin/env ruby

class Base85

  # Encodes data using Base64, used to convert binary data into text
  def self.encode(string)

    # Data must be padded to specific byte sizes before conversion
    def self.pad(string, alignment)
      next_multiple = ((string.size / alignment) + 1) * alignment
      padding_bytes = next_multiple - string.size
      padding_bytes = alignment if padding_bytes == 0
      string + (padding_bytes.chr * padding_bytes)
    end

    string = pad(string, 4)

    result = ""
    byte_nbr = 0
    value = 0

    # Walk through the data and convert each binary block into text
    while byte_nbr < string.size
      value = (value * 256) + string[byte_nbr].unpack("C")[0]
      byte_nbr += 1
      if byte_nbr % 4 == 0
        divisor = 85 * 85 * 85 * 85
        while divisor >= 1
          idx = (value / divisor).floor % 85
          result += SAFE85[idx]
          divisor /= 85
        end
        value = 0
      end
    end

    result
  end

  # Decode Base85 text back to binary.
  def self.decode(string)

    dest = []
    byte_nbr = 0
    char_nbr = 0
    value = 0

    # Walk through the text and convert each block back to binary
    while char_nbr < string.size
      idx = string[char_nbr].ord - 32
      value = (value * 85) + DECODER[idx]
      char_nbr += 1
      if char_nbr % 5 == 0
        divisor = 256 * 256 * 256
        while divisor >= 1
          dest[byte_nbr] = (value / divisor) % 256
          byte_nbr += 1
          divisor /= 256
        end
        value = 0
      end
    end

    # The data will need to have the padding removed
    def self.unpad(string)
      last_byte = string[-1].unpack("c")[0]
      string[0..(string.size - last_byte - 1)]
    end

    unpad(dest.pack("C*"))
  end

  private

  def self.generate_decoder
    decoder = []
    SAFE85.chars.each_with_index do |c,i|
      decoder[c.ord-32]=i
    end
    decoder.map{|i| i.nil? ? 0 : i}
  end

    # Alphabet used for Base85/Safe85 encoding / decoding
  SAFE85  = "!$()*+,-.0123456789:;=>@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_`abcdefghijklmnopqrstuvwxyz{|}~"
  DECODER = generate_decoder

end
