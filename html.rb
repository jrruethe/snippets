#!/usr/bin/env ruby

class String

  def normalize
    self.downcase.gsub(/[^0-9a-z\.\-]/, "_")
  end

  def friendly
    t = self.gsub("_", " ")
    if t == t.upcase
      return t
    else
      m = t.match(/<.*>(.*)<\/.*>/)

      if m.nil?
        return t.capitalize
      else
        return t.gsub(m[1], m[1].capitalize)
      end

    end
  end

  def tag(type, attributes = {})

    # Map attributes to a string
    a =
    attributes.map do |pair|
      key, value = pair
      "#{key}=\"#{value}\""
    end
    .join(" ")

    # Prepend a space
    a = " " + a unless a.empty?

    return "<#{type}#{a}>#{self}</#{type}>"
  end

  def link(target = nil)
    self.tag("a", {"href" => target || "/?query=#{self}"})
  end

  def color(value)
    self.tag("font", {"color" => value})
  end

  def red
    self.color("AA0000")
  end

  def green
    self.color("00AA00")
  end

  def gray
    self.color("AAAAAA")
  end

  def indent(length)
    self.split("\n").map do |i|
      "#{"  " * length}#{i}"
    end
    .join("\n")
  end

  def to_html(depth = 0)
    self.indent(depth)
  end

  # Turn a URI into a loading button
  def to_button
    id = "load_" + ("a".."z").to_a.shuffle[0, 8].join
    "
    <div id=\"#{id}\">
      <center>
        <input type=\"button\" value=\"Load\" onclick=\"load('#{id}', '#{self}');\" />
      </center>
    </div>
    "
  end

  def autoload
    id = "autoload_" + ("a".."z").to_a.shuffle[0, 8].join
    "
    <div id=\"#{id}\">
      <center>
        <input type=\"button\" value=\"Load\" onclick=\"load('#{id}', '#{self}');\" />
      </center>
    </div>
    "
  end

end

class Symbol
  def friendly
    return self.to_s.friendly
  end
end

# There is no "Boolean" class that TrueClass and FalseClass derive from,
# so using Object as the base class.
class Object

  def is_bool?
    self.is_a?(TrueClass) || self.is_a?(FalseClass)
  end

  # This converts boolean values to human friendly strings with color
  def humanize(t = "yes", f = "no")
    return self unless self.is_bool?
    return self ? t.capitalize.green : f.capitalize.red
  end

  # Invert the color
  def invert_color
    return self unless self.is_bool?
    return InvertedColorBoolean.new(self)
  end

end

# A simple wrapper around a boolean
class InvertedColorBoolean

  def initialize(value)
    @value = value
  end

  def is_bool?
    @value.is_a?(TrueClass) || @value.is_a?(FalseClass)
  end

  # This converts boolean values to human friendly strings with color
  def humanize(t = "yes", f = "no")
    return @value unless @value.is_bool?
    return @value ? t.capitalize.red : f.capitalize.green
  end

end

class NilClass

  def humanize(t = "yes", f = "no")
    "Unknown".gray
  end

  def to_html(depth = 0)
    self.humanize.to_html(depth)
  end

end

class TrueClass

  def to_html(depth = 0)
    self.humanize.to_html(depth)
  end

end

class FalseClass

  def to_html(depth = 0)
    self.humanize.to_html(depth)
  end

end

class Integer

  def to_html(depth = 0)
    self.to_s.to_html(depth)
  end

end

class Float

  def to_html(depth = 0)
    self.to_s.to_html(depth)
  end

end

class Array

  def is_array_of?(c)
    self.map{|i| i.is_a?(c)}.all?
  end

  def is_matrix?
    is_array_of?(Array)
  end

  def to_table

    # If this is an array of hashes
    # and all the elements are the same size
    # and none of the elements are nested
    if self.is_array_of?(Hash)             &&
       self.map{|i| i.size}.uniq.size == 1 &&
       self.map{|i| i.is_nested?}.none?

      # Assume all entries in the array are the same structure.
      # Derive the headers from the first entry
      headers = self.first.keys.map{|i| i.friendly}

      # Convert each object into a table row
      return self.map{|i| i.values}.unshift(headers)

    else
      # Cannot convert the array of hashes into a table.
      return self
    end
  end

  def to_html(depth = 0)

    # Convert booleans to human friendly strings with color
    this = self.humanize

    # See if we can convert ourselves to a table
    table = this.to_table

    # If matrix, make a table
    return table.to_html_table(depth, true) if table.is_matrix?

    # If this is an array of strings or numbers, make an unordered list
    if this.is_array_of?(String)  ||
       this.is_array_of?(Integer) ||
       this.is_array_of?(Float)

      retval = []
      retval << "<ul>".indent(depth)
      this.each do |i|
        retval << i.to_s.tag("li").indent(depth + 1)
      end
      retval << "</ul>".indent(depth)
      return retval.join("\n")

    # This seems to be an array of random objects
    else

      retval = ["\n"]
      retval << "<table>".indent(depth)
      retval << "<tbody>".indent(depth + 1)
      this.each do |row|
        retval << "<tr>".indent(depth + 2)
        retval << "<td>".indent(depth + 3)
        retval << row.to_html(depth + 4)
        retval << "</td>".indent(depth + 3)
        retval << "</tr>".indent(depth + 2)
      end
      retval << "</tbody>".indent(depth + 1)
      retval << "</table>".indent(depth)
      return retval.join("\n")

    end
  end

  def to_html_table(depth = 0, sortable = false)
    retval = ["\n"]

    if sortable

      # Make a sortable table
      id = "sortable_table_" + ("a".."z").to_a.shuffle[0, 8].join
      retval << "<table id=\"#{id}\">".indent(depth)

      # First row is a header
      first, rest = self[0], self[1..-1]

      # Add the header
      retval << "<thead>".indent(depth + 1)
      retval << "<tr>".indent(depth + 2)
      first.each do |col|
        retval << col.to_s.tag("th").indent(depth + 3)
      end
      retval << "</tr>".indent(depth + 2)
      retval << "</thead>".indent(depth + 1)

    else

      # Make a normal table
      retval << "<table>".indent(depth)

      rest = self
    end

    # Add the body
    retval << "<tbody>".indent(depth + 1)
    rest.each do |row|
      retval << "<tr>".indent(depth + 2)
      row.each do |col|
        retval << col.to_s.tag("td").indent(depth + 3)
      end
      retval << "</tr>".indent(depth + 2)
    end
    retval << "</tbody>".indent(depth + 1)

    retval << "</table>".indent(depth)
    return retval.join("\n")
  end

  # Recurse convert all booleans to friendly strings
  def humanize(t = "yes", f = "no")
    return "Empty".gray if self.empty?
    self.each_with_object([]) do |i, a|
      a << i.humanize(t, f)
    end
  end

end

class Hash

  def hmap(&block)
    Hash[self.map{|k, v| block.call(k,v)}]
  end

  def to_html(depth = 0)
    retval = []

    # Convert booleans to human friendly strings with color
    this = self.humanize

    # First, pull out all the top-level values
    top = this.reject{|k, v| [Hash, Array].include?(v.class) && !v.empty?}

    # Format the keys
    top = top.hmap{|k, v| ["#{k.friendly}:", v]}

    # Convert it into a table
    retval << top.to_a.to_html_table(depth)

    # Then, recurse into the nested structures
    objects = this.select{|k, v| [Hash, Array].include?(v.class) && !v.empty?}
    objects.each do |k, v|
      retval << [["#{k.friendly}".tag("b").tag("p", {"align" => "center"}), v.to_html(depth)]].transpose.to_html_table(depth)
    end

    return retval.join("\n")
  end

  def is_nested?
    self.values.map{|i| [Hash, Array].include?(i.class)}.any?
  end

  # Recurse and convert all booleans to friendly strings
  def humanize(t = "yes", f = "no")
    return "Empty".gray if self.empty?
    self.each_with_object({}) do |(k, v), h|
      h[k] = v.humanize(t, f)
    end
  end

end
