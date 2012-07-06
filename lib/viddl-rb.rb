#!/usr/bin/env ruby
$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'helper')

require "rubygems"
require "nokogiri"
require "mechanize"
require "cgi"
require "open-uri"
require "stringio"
require "download-helper.rb"
require "plugin-helper.rb"

#require all plugins
Dir[File.join(File.dirname(__FILE__),"../plugins/*.rb")].each { |p| require p }

module ViddlRb
  class PluginError < StandardError; end

  def self.io=(io_object)
    PluginBase.io = io_object
  end

  #set the default PluginBase io objec to a StringIO instance.
  #this will suppress any standard output from the plugins.
  self.io = StringIO.new
  
  #returns an array of hashes containing the download url(s) and filenames(s) 
  #for the specified video url.
  #if the url does not match any plugin, return nil and if a plugin
  #throws an error, throw PluginError.
  #the reason for returning an array is because some urls will give multiple
  #download urls (for example a Youtube playlist url).
  def self.get_urls_and_filenames(url)
    plugin = PluginBase.registered_plugins.find { |p| p.matches_provider?(url) }

    if plugin 
      begin
        #we'll end up with an array of hashes with they keys :url and :name
        urls_filenames = plugin.get_urls_and_filenames(url)
      rescue StandardError => e
        message = plugin_error_message(plugin, e.message)
        raise PluginError, message
      end
      urls_filenames
    else
      nil
    end
  end

  #returns an array of download urls for the given video url.
  def self.get_urls(url)
    urls_filenames = get_urls_and_filenames(url)
    urls_filenames.nil? ? nil : urls_filenames.map { |uf| uf[:url] }
  end

  #returns an array of filenames for the given video url.
  def self.get_filenames(url)
    urls_filenames = get_urls_and_filenames(url)
    urls_filenames.nil? ? nil : urls_filenames.map { |uf| uf[:name] }
  end

  #<<< helper methods >>>

  #the default error message when a plugin fails to download a video.
  def self.plugin_error_message(plugin, error)
    "Error while running the #{plugin.name.inspect} plugin. Maybe it has to be updated? Error: #{error}."
  end
  private_class_method :plugin_error_message
end
