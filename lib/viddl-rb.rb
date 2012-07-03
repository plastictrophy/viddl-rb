#!/usr/bin/env ruby
$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'helper')

require "rubygems"
require "nokogiri"
require "mechanize"
require "cgi"
require "open-uri"
require "open3"
require "stringio"
require "download-helper.rb"
require "plugin-helper.rb"

Dir[File.join(File.dirname(__FILE__),"../plugins/*.rb")].each { |p| load p }


module ViddlRb

  class PluginError < StandardError; end

  #returns an array of download urls for the specified video url
  #if the url does not match any plugin, return nil and if a plugin
  #throws an error, throw PluginError
  def self.get_urls(url)
    plugin = PluginBase.registered_plugins.find { |p| p.matches_provider?(url) }

    if plugin 
      begin
        #we'll end up with an array of hashes with they keys :url and :name
        #surpress_stdout makes sure that plugins don't print to $stdout
        download_queue = suppress_stdout { plugin.get_urls_and_filenames(url) }
      rescue StandardError => e
        message = "Error while running the #{plugin.name.inspect} plugin. Maybe it has to be updated? Error: #{e.message}."
        raise PluginError, message
      end
      download_queue.map { |url_name| url_name[:url] }
    else
      nil
    end
  end

  #redircts $stdout calls (for example puts) for the given block
  #to a temporary StringIO object.
  def self.suppress_stdout
    std = $stdout
    $stdout = StringIO.new
    begin
      return_value = yield
    ensure
      $stdout = std
      return_value
    end
  end
  private_class_method :suppress_stdout

end