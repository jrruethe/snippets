#!/usr/bin/env ruby

require "base64"
require "openssl"
require "uri"

def curl(id:      nil,
         key:     nil,
         type:    nil,
         host:    nil,
         region:  nil,
         service: nil,
         version: nil,
         path:    nil,
         query:   nil,
         data:    nil,
         content: nil,
         file:    nil)

  # Build the URL
  url = "https://#{host}#{path}"
  url += "?#{URI.encode_www_form(query)}" unless query.empty?

  # Get the current datetime
  datetime = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")

  # Create the headers
  headers = generate_headers(host, datetime, content, data)

  # 1) Create a canonical request
  request = generate_canonical_request(type, path, query, headers, data)

  # 2) Create the string to sign
  string_to_sign = generate_string_to_sign(datetime, region, service, request)

  # 3) Sign the message
  signature = generate_signature(string_to_sign, key, datetime, region, service)

  # Build the authorization header
  authorization = authorization(id, headers, datetime, region, service, signature)

  # Build the curl command
  [
    %Q{curl -s -X #{type}},
    headers.map{|k,v| %Q{-H "#{k}: #{v}"}}.join(" "),
    %Q{-H "Authorization: #{authorization}"},
    file ? %Q{-T "#{file}"} : data.empty? ? "" : %Q{-d "#{data}"},
    %Q{"#{url}"}
  ]
  .join(" ")
end

def generate_headers(host, datetime, content, data = "")

  retval =
  {
    "Accept"               => "application/json",
    "Host"                 => host,
    "X-Amz-Date"           => datetime,
    "Content-Type"         => content,
    "X-Amz-Content-SHA256" => OpenSSL::Digest::SHA256.hexdigest(data)
  }

  unless data.empty?
    retval["Content-Length"] = data.length
    retval["Content-MD5"]    = Base64.strict_encode64(OpenSSL::Digest::MD5.digest(data))
  end

  retval.map{|k, v| [k.downcase, v]}.sort.to_h
end

# No need to change
def generate_canonical_request(type, path, parameters, headers, data)
  [
    type,
    path,
    URI.encode_www_form(parameters.sort),
    headers.map{|k,v| "#{k}:#{v}"}.join("\n"),
    "",
    headers.keys.join(";"),
    OpenSSL::Digest::SHA256.hexdigest(data)
  ]
  .join("\n")
end

# No need to change
def scope(datetime, region, service)
  [datetime[0..7], region, service, "aws4_request"]
end

# No need to change
def generate_string_to_sign(datetime, region, service, request)
  [
    "AWS4-HMAC-SHA256",
    datetime,
    scope(datetime, region, service).join("/"),
    OpenSSL::Digest::SHA256.hexdigest(request)
  ]
  .join("\n")
end

# No need to change
def generate_signature(string_to_sign, key, datetime, region, service)
  signing_key = (["AWS4" + key] + scope(datetime, region, service))
  .reduce{|k, i| OpenSSL::HMAC.digest("SHA256", k, i)}
  OpenSSL::HMAC.hexdigest("SHA256", signing_key, string_to_sign)
end

# No need to change
def authorization(id, headers, datetime, region, service, signature)
  [
    "AWS4-HMAC-SHA256",
    "Credential=#{id}/#{scope(datetime, region, service).join("/")},",
    "SignedHeaders=#{headers.keys.join(";")},",
    "Signature=#{signature}",
  ]
  .join(" ")
end

if $0 == __FILE__
  require "optparse"
  require "ostruct"
  require "json"

  options = OpenStruct.new
  OptionParser.new do |opts|
    opts.on("-i", "--id AWS_ACCESS_KEY_ID",      "AWS Access Key ID")                 {|i| options.id      = i}
    opts.on("-k", "--key AWS_SECRET_ACCESS_KEY", "AWS Secret Access Key")             {|k| options.key     = k}
    opts.on("-t", "--type TYPE",                 "HTTP type (POST)")                  {|t| options.type    = t}
    opts.on("-h", "--host HOST",                 "Host (ec2.us-east-1.amazonaws.com)"){|h| options.host    = h}
    opts.on("-r", "--region REGION",             "Region (us-east-1)")                {|r| options.region  = r}
    opts.on("-s", "--service SERVICE",           "Service (ec2)")                     {|s| options.service = s}
    opts.on("-v", "--version VERSION",           "Version (2016-11-15)")              {|v| options.version = v}
    opts.on("-p", "--path PATH",                 "Path (/)")                          {|p| options.path    = p}
    opts.on("-q", "--query QUERY",               "Query Parameters ({})")             {|q| options.query   = JSON.parse q}
    opts.on("-d", "--data DATA",                 "Data Payload ({})")                 {|d| options.data    = JSON.parse d}
    opts.on("-a", "--action ACTION",             "API Action (DescribeInstances)")    {|a| options.action  = a}
    opts.on("-c", "--content CONTENT",           "Content Type (application/json)")   {|c| options.content = c}
    opts.on("-b", "--bucket BUCKET",             "Bucket (test)")                     {|b| options.bucket  = b}
    opts.on("-f", "--file FILE",                 "File (./file.json)")                {|f| options.file    = f}

    opts.separator "
    Describe EC2 instances : curl.rb -a DescribeInstances
    Upload file to S3      : curl.rb -b BUCKET -f ./FILE -p /PATH/TO/WRITE
    Download file from S3  : curl.rb -b BUCKET -p /PATH/TO/FILE
    "
  end.parse!

  version_map =
  {
    "ec2"                  => "2016-11-15",
    "s3"                   => "2006-03-01",
    "elasticloadbalancing" => "2015-12-01",
  }

  # Set defaults for EC2
  options.id      ||= ENV["AWS_ACCESS_KEY_ID"]
  options.key     ||= ENV["AWS_SECRET_ACCESS_KEY"]
  options.region  ||= "us-east-1"
  options.service ||= "ec2"
  options.version ||= version_map[options.service]
  options.type    ||= "POST"
  options.path    ||= "/"
  options.query   ||= {}

  # Modify defaults for S3
  if options.bucket
    options.service = "s3"
    options.type = options.file ? "PUT" : "GET"
  end

  case options.service
  when "s3"; options.host ||= "#{options.bucket}.s3.amazonaws.com"
  else;      options.host ||= "#{options.service}.#{options.region}.amazonaws.com"
  end

  if options.file
    options.data    ||= File.read(options.file)
    options.content ||= "application/octet-stream"
  elsif options.action
    x = {"Action" => options.action, "Version" => options.version}
    options.data    ||= URI.encode_www_form(x)
    options.content ||= "application/x-www-form-urlencoded"
  else
    options.data    ||= ""
    options.content ||= "application/json"
  end

  # Validate arguments
  abort("Must specify AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY") unless options.id && options.key
  abort("Must specify a path") if options.service == "s3" && options.path.end_with?("/")

  # Show results
  puts curl(**options.to_h.reject{|k,v| [:action, :bucket].include?(k)})
end
