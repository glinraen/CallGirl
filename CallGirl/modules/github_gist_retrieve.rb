#!/usr/bin/env ruby -wKU

# gist

# 
# This script allows you to get, list, create, and update Github gists
# from the command line. There are others like this but this one caches
# file names to gist mappings so you do not need to remember them. The 
# cache is just a YAML file in ~/.gists. This script also leaves
# the URL of the last gist accessed on the clipboard.
#
# WARNING: This only works with files in the current folder, paths are
# not supported in gists.
#
# WARNING: `get` supports multiple file gists but `create` and `update`
# work on single files only
#
# Prerequisites:
# You need to get your github user and pasword in either:
# - In git's global config as github.user and github.password
# - In your envronment as GITHUB_USER and GITHUB_PASSWORD
#
# Usage:
# gist get <id>           -> retrieves the numbered gist (if possible) and writes the file locally
# gist create <file_name> -> creates a new gist of the file and returns the gist_id
# gist update <file_name> -> updates an existing gist of the file and returns the gist_id
# gist url <file_name>    -> gets the gist URL for a file
# gist id <file_name>     -> Displays the ID for a file from the cache
# gist list <user_name>   -> Lists up to 100 gists for a given user name (API limit)
# gist view <id>          -> displays the gist to stdout
# gist raw <id>           -> returns the raw JSON for a gist_id

require 'net/https'
require 'uri'
require 'json'
require 'optparse'
require 'yaml'
require 'fileutils'

class Gist
  
  VERSION = '0.1.1'
  AUTHOR = "SJK, BMN CORP"
  ORIGAUTHOR = 'Mr.Lip Schitz'
  TWITTER = '@cybersanctuary'
  HOME_URL = 'http://www.baremetalnetworks.com'
  LEDE = 'Create, Retrieve and Update Gists'
  
  GIST_URL   = 'https://api.github.com/gists'
  WEB_URL   = 'https://gist.github.com'
  USER_URL   = 'https://api.github.com/users/%s/gists'
  CACHE_FILE_PATH = "#{ENV['HOME']}/.gists"
  
  attr_reader :options
  
  def initialize(arguments)
    @arguments = arguments
    
    parse_options
    parse_commands
  end
  
  def run
    case @command
    when 'CREATE'
      execute_create_gist_command
    when 'GET'
      execute_get_gist_command
    when 'ID'
      execute_id_gist_command
    when 'LIST'
      execute_list_gists_command
    when 'UPDATE'
      execute_update_gist_command
    when 'URL'
      execute_url_gist_command
    when 'VIEW'
      execute_view_gist_command
    when 'RAW'
      puts retrieve_gist(@parameter)
    else
      puts @opts
    end
  end
  
  protected
  
  def execute_create_gist_command
    return if no_auth? || no_file?(@parameter)
    
    response = api_post_request([@parameter])
    unless response.nil?
      gist_id = response["id"]
      cache_gist(gist_id, [@parameter])
      to_pasteboard(gist_id)
      puts "#{gist_id} Created..."
    end
  end
  
  def execute_get_gist_command
    data = retrieve_gist @parameter
    unless data.nil?
      files_array = []
      data["files"].keys.each do |key|
        content = extract_content(data, key)
        file_name = extract_file_name(data, key)
        File.open(file_name, "w") do |f| # Ruby 1.8 Style (not IO.write)
          f << content
        end
        files_array << file_name
      end
      cache_gist(@parameter, files_array)
      to_pasteboard(@parameter)
      puts "Retrieved #{files_array.join(',')}"
    end
  end
  
  def execute_id_gist_command
    gist_id = get_id_from_cache(@parameter)
    to_pasteboard(gist_id)
    puts gist_id
  end
  
  def execute_list_gists_command
    response = api_get_request(USER_URL % @parameter)
    unless response.nil?
      response.each do |line|
        files_array = []
        line["files"].keys.each do |key|
          files_array << key
        end
        puts "#{line['id']},#{files_array.join(',')}"
      end
    end
  end
  
  def execute_update_gist_command
    gist_id = get_id_from_cache(@parameter)
    if gist_id.nil?
      puts "Unable to figure out the Gist ID, GET the gist to cache the ID first."
      return
    end
    
    return if no_auth? || no_file?(@parameter)
    
    response = api_post_request([@parameter], gist_id)
    unless response.nil?
      to_pasteboard(gist_id)
      puts "#{gist_id} Updated..."
    end
  end
  
  def execute_url_gist_command
    gist_id = get_id_from_cache(@parameter)
    unless gist_id.nil?
      text = "#{WEB_URL}/#{gist_id}" 
      to_pasteboard(gist_id)
      puts text
    end
  end

  def execute_view_gist_command
    data = retrieve_gist @parameter
    unless data.nil?
      data["files"].keys.each do |key|
        puts "\n\n#{extract_file_name(data, key)}\n" if data["files"].keys.length > 1
        puts extract_content(data, key)
      end
      to_pasteboard(@parameter)
    end
  end
  
  def retrieve_gist(params)
    api_get_request(GIST_URL + "/#{params}")
  end
  
  def extract_content(data, key)
    data["files"][key]["content"]
  end

  def extract_file_name(data, key)
    data["files"][key]["filename"]
    # data["files"].map{|name, content| content['filename'] }.join("\n\n")
  end
  
  def api_get_request(url, params = nil)
    uri = URI(url)
    uri.query = URI.encode_www_form(params) if params
        
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    
    request = Net::HTTP::Get.new(uri.request_uri)
    request.add_field('User-Agent', 'TextMate Gists Bundle')
    
    response = http.request(request)
    if response.code.to_i >= 300
      puts "Failed: #{response.code}: #{response.body}"
      return nil
    end
    JSON.parse(response.body)
  end
  
  def api_post_request(file_names, id = nil)
    url = GIST_URL
    url = "#{url}/#{id}" unless id.nil?
    uri = URI(url)
    # puts uri
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.request_uri)
    request.add_field('User-Agent', 'TextMate Gists Bundle')
    request.body = JSON.generate(make_data(file_names, nil))
    request["Content-Type"] = "application/json"
    user, password = auth()
    if user && password
      request.basic_auth(user, password)
    end

    response = http.request(request)
    # puts response.code
    # puts response.body
    if response.code.to_i >= 300
      puts "Failed: #{response.code}: #{response.body}"
      return nil
    end
    JSON.parse(response.body)
  end
  
  def make_data(file_names, description)
    file_data = {}
    file_names.each do |file_name|
      file_data[File.basename(file_name)] = {:content => IO.read(file_name).to_s }
    end

    data = {"files" => file_data}
    data.merge!({ 'description' => description }) unless description.nil?
    data.merge!({ 'public' => !options[:private]})
    data
  end
  
  def no_auth?
    user, password = auth()
    if user.to_s.empty? || password.to_s.empty?
      puts "Unable to proceed, you need to set your Github User and Password. Either set github.user and github.password in your global git config, or set GITHUB_USER and GITHUB_PASSWORD in the environment."
      return true
    end
    false # Ok to proceed
  end
    
  def auth
    user = `git config --global github.user`.strip
    user = ENV['GITHUB_USER'] if user.to_s.empty?

    password = `git config --global github.password`.strip
    password = ENV['GITHUB_PASSWORD'] if password.to_s.empty?
     
    [ user, password ]
  end
  
  def no_file?(file_name)
    unless File.exists?(file_name)
      puts "Unable to open the file #{file_name}."
      return true
    end
    false
  end
   
  def load_cache
    if File.exists?(CACHE_FILE_PATH)
      YAML.load_file(CACHE_FILE_PATH)
    else
      {} # New Hash
    end
  end
  
  def save_cache(cache_array)
    FileUtils.touch(CACHE_FILE_PATH)
    File.open(CACHE_FILE_PATH, "w") do |f| # Ruby 1.8 Style (not IO.write)
      f << cache_array.to_yaml
    end
  end
  
  def cache_gist(gist_id, files_array)
    cache = load_cache
    cache[gist_id] = files_array.join(',')
    save_cache(cache)
  end
  
  def get_id_from_cache(file_name)
    cache = load_cache
    cache.keys.each do |key|
      return key if cache[key].split(',').index(file_name)
    end
    nil
  end
  
  def to_pasteboard(gist_id)
    return unless RUBY_PLATFORM =~ /darwin/
    text = "#{WEB_URL}/#{gist_id}" 
    IO.popen('pbcopy', 'r+').puts text
  end
  
  def parse_options
    @options = { :private => false }
    
    title = "#{LEDE}\nBy #{AUTHOR} (#{TWITTER}) #{HOME_URL}\n"
    
    @opts = OptionParser.new
    @opts.banner = "#{title}\nUsage: gist [options] command parameter"
      @opts.separator ""
      @opts.separator  "Commands"
      @opts.separator  "    create <file_name>: Creates a gist"
      @opts.separator  "    get <gist_id>: retrieves all the files in a gist and creates them locally"
      @opts.separator  "    id <file_name>: shows the cached gist_id for a file or nothing"
      @opts.separator  "    list <user>: Lists all the gists by user id"
      @opts.separator  "    update <file_name>: Updates a gist with this file if cached"
      @opts.separator  "    view <gist_id>: displays the files in the gist by id"
      @opts.separator  "    url <file_name>: shows the cached url for a file or nothing"
      @opts.separator  "    raw <gist_id>: displays the raw json retrieved from github"
      @opts.separator  ""
      @opts.separator  "Options"
    @opts.on("-p", "--[no-]private", "Private Gists") { |p| options[:private] = p }
    @opts.on('-h', '--help', 'Display this screen' ) { puts @opts; exit 0 }
    begin
      @opts.parse!(@arguments) 
    rescue => e
      puts e
      puts
      puts @opts
      exit(-1)
    end
  end
  
  def parse_commands
    if @arguments.empty?
      puts @opts
      exit(-1)
    end

    @command = ARGV[0].upcase

    # TODO: Handle stdin for some commands
    if @arguments.length < 2
      puts "Command #{@command} requires a parameter...\n\n"
      puts @opts
      exit(-1)
    end
    
    @parameter = ARGV[1]
  end
  
end

app = Gist.new(ARGV)
app.run
