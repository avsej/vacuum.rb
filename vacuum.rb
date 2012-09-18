#!/usr/bin/env ruby

require 'rubygems'
begin
  require 'bundler/setup'
rescue LoadError
  # don't worry if bundler isn't available
  # the script could be installed somewhere in PATH
end
require 'couchbase'
require 'yajl'
require 'rev'
require 'pathname'
require 'optparse'
require 'logger'

options = {
  :verbose => false,
  :spool_directory => "/var/spool/vacuum",
  :host => "127.0.0.1:8091",
  :bucket => "default"
}

trap("INT") do
  LOGGER.info("Caught SIGINT. Terminating...")
  exit
end

class Watcher < Rev::StatWatcher
  def initialize(options)
    @options = options
    begin
      @spool_directory = Pathname(@options[:spool_directory]).realpath
    rescue Errno::ENOENT => ex
      LOGGER.error(ex)
      exit(-1)
    end
    super(@spool_directory.to_s)
    attach(Rev::Loop.default)
    begin
      @database = Couchbase.new(:hostname => options[:hostname],
                                :port => options[:port],
                                :bucket => options[:bucket])
    rescue Couchbase::Error::Base => ex
      LOGGER.error(ex)
      exit(-1)
    end
  end

  def each_change
    @spool_directory.each_child do |child|
      if child.file? && !child.basename.to_s.start_with?('.')
        yield(child.expand_path.to_s, child.read)
        child.unlink
      end
    end
  rescue Errno::ENOENT
  end

  def on_change
    LOGGER.info("spool directory modification detected")
    each_change do |filename, contents|
      begin
        LOGGER.info("processing file #{filename}")
        document = Yajl::Parser.parse(contents)
        id = filename[%r{/([^/]*)\.json$}, 1]
        @database.set(id, document)
        LOGGER.info("The document #{id} successfully stored")
      rescue Couchbase::Error::Base
        LOGGER.error("cannot store the document: #{filename}")
      rescue Yajl::ParseError
        LOGGER.error("cannot parse JSON: #{filename}")
      end
    end
  end

  def run
    LOGGER.info("listening changes on #{@spool_directory}")
    Rev::Loop.default.run
  end
end

OptionParser.new do |opts|
  opts.banner = "Usage: vacuum.rb [options]"
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
  opts.on("-h", "--hostname HOSTNAME", "Hostname to connect to (default: #{options[:hostname]})") do |v|
    host, port = v.split(':')
    options[:hostname] = host.empty? ? '127.0.0.1' : host
    options[:port] = port.to_i > 0 ? port.to_i : 8091
  end
  opts.on("-u", "--user USERNAME", "Username to log with (default: none)") do |v|
    options[:user] = v
  end
  opts.on("-p", "--passwd PASSWORD", "Password to log with (default: none)") do |v|
    options[:passwd] = v
  end
  opts.on("-b", "--bucket NAME", "Name of the bucket to connect to (default: #{options[:bucket]})") do |v|
    options[:bucket] = v.empty? ? "default" : v
  end
  opts.on("-s", "--spool-directory DIRECTORY", "Location of spool directory (default: #{options[:spool_directory]})") do |v|
    options[:spool_directory] = v
  end
  opts.on_tail("-?", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

LOGGER = Logger.new(STDERR)
LOGGER.level = options[:verbose] ? Logger::INFO : Logger::ERROR

watcher = Watcher.new(options)
watcher.on_change
watcher.run
