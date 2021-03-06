module ViddlRb
  class Youtube < PluginBase
    #this will be called by the main app to check whether this plugin is responsible for the url passed
    def self.matches_provider?(url)
      url.include?("youtube.com") || url.include?("youtu.be")
    end
    
    #get all videos and return their urls in an array
    def self.get_video_urls(feed_url)
      puts "[YOUTUBE] Retrieving videos..."
      urls_titles = Hash.new
      result_feed = Nokogiri::HTML(open(feed_url))
      urls_titles.merge!(grab_ut(result_feed))

      #as long as the feed has a next link we follow it and add the resulting video urls
      loop do   
        next_link = result_feed.search("//feed/link[@rel='next']").first
        break if next_link.nil?
        result_feed = Nokogiri::HTML(open(next_link["href"]))
        urls_titles.merge!(grab_ut(result_feed))
      end

      self.filter_urls(urls_titles)
    end

    #returns only the urls that match the --filter argument regex (if present)
    def self.filter_urls(url_hash)
      #get the --filter arg or "" if it is not present (because nil would break the next line)
      filter = ARGV.find( proc {""} ) { |arg| arg =~ /--filter=/ }
      regex = filter[/--filter=(.+?)(?:\/|$)/, 1]
      if regex
        puts "[YOUTUBE] Using filter: #{regex}"
        ignore_case = filter.include?("/i")
        filtered = url_hash.select { |url, title| title =~ Regexp.new(regex, ignore_case) }
        filtered.keys
      else
        url_hash.keys
      end
    end

    #extract all video urls and their titles from a feed and return in a hash
    def self.grab_ut(feed)
      feed.remove_namespaces!  #so that we can get to the titles easily
      urls   = feed.search("//entry/link[@rel='alternate']").map { |link| link["href"] }
      titles = feed.search("//entry/group/title").map { |title| title.text } 
      Hash[urls.zip(titles)]    #hash like this: url => title
    end

    def self.parse_playlist(url)
      #http://www.youtube.com/view_play_list?p=F96B063007B44E1E&search_query=welt+auf+schwäbisch
      #http://www.youtube.com/watch?v=9WEP5nCxkEY&videos=jKY836_WMhE&playnext_from=TL&playnext=1
      #http://www.youtube.com/watch?v=Tk78sr5JMIU&videos=jKY836_WMhE

      playlist_ID = url[/(?:list=PL|p=)(\w{16})&?/,1]
      puts "[YOUTUBE] Playlist ID: #{playlist_ID}"
      feed_url = "http://gdata.youtube.com/feeds/api/playlists/#{playlist_ID}?&max-results=50&v=2"
      url_array = self.get_video_urls(feed_url)
      puts "[YOUTUBE] #{url_array.size} links found!"
      url_array
    end

    def self.parse_user(username)
      puts "[YOUTUBE] User: #{username}"
      feed_url = "http://gdata.youtube.com/feeds/api/users/#{username}/uploads?&max-results=50&v=2"
      url_array = get_video_urls(feed_url)
      puts "[YOUTUBE] #{url_array.size} links found!"
      url_array
    end

    def self.get_urls_and_filenames(url)
      return_values = []
      if url.include?("view_play_list") || url.include?("playlist?list=")    #if playlist
        puts "[YOUTUBE] playlist found! analyzing..."
        files = self.parse_playlist(url)
        puts "[YOUTUBE] Starting playlist download"
        files.each do |file|
          puts "[YOUTUBE] Downloading next movie on the playlist (#{file})"
          return_values << self.grab_single_url_filename(file)
        end  
      elsif match = url.match(/\/user\/([\w\d]+)$/)                          #if user url, e.g. youtube.com/user/woot
        username = match[1]
        video_urls = self.parse_user(username)
        puts "[YOUTUBE] Starting user videos download"
        video_urls.each do |url|
          puts "[YOUTUBE] Downloading next user video (#{url})"
          return_values << self.grab_single_url_filename(url)
        end
      else                                                                   #if single video
        return_values << self.grab_single_url_filename(url)
      end
     
      return_values.reject! { |value| value == :no_embed }   #remove results that can not be downloaded
      return_values.empty? ? exit : return_values            #if no videos could be downloaded exit 
    end
   
    def self.grab_single_url_filename(url)
      #the youtube video ID looks like this: [...]v=abc5a5_afe5agae6g&[...], we only want the ID (the \w in the brackets)
      #addition: might also look like this /v/abc5-a5afe5agae6g
      # alternative:  video_id = url[/v[\/=]([\w-]*)&?/, 1]
      # First get the redirect
      if url.include?("youtu.be")
        url = open(url).base_uri.to_s
      end
      video_id = url[/(v|embed)[\/=]([^\/\?\&]*)/,2]
      if video_id.nil?
        puts "no video id found."
        exit
      else
        puts "[YOUTUBE] ID FOUND: #{video_id}"
      end
      #let's get some infos about the video. data is urlencoded
      yt_url = "http://www.youtube.com/get_video_info?video_id=#{video_id}"
      video_info = open(yt_url).read
      #converting the huge infostring into a hash. simply by splitting it at the & and then splitting it into key and value arround the =
      #[...]blabla=blubb&narf=poit&marc=awesome[...]
      video_info_hash = Hash[*video_info.split("&").collect { |v| 
        key, encoded_value = v.split("=")
        if encoded_value.to_s.empty?
          value = ""
        else
        #decode until everything is "normal"
          while (encoded_value != CGI::unescape(encoded_value)) do
            #"decoding"
            encoded_value = CGI::unescape(encoded_value)
          end
          value = encoded_value
        end

        if key =~ /_map/
          orig_value = value
          value = value.split(",")
          if key == "url_encoded_fmt_stream_map"
            url_array = orig_value.split("url=").map{|url_string| url_string.chomp(",")}
            result_hash = {}
            url_array.each do |url|
              next if url.to_s.empty?
              format_id = url.match(/\&itag=(\d+)/)[1]
              result_hash[format_id] = url
            end
            value = result_hash
          elsif key == "fmt_map"
            value = Hash[*value.collect { |v| 
                k2, *v2 = v.split("/")
                [k2, v2]
              }.flatten(1)]
          elsif key == "fmt_url_map" || key == "fmt_stream_map"
            Hash[*value.collect { |v| v.split("|")}.flatten]
          end
        end
        [key, value]
      }.flatten]
      
      if video_info_hash["status"] == "fail"
        puts "Error: embedding disabled, no video info found"
        return :no_embed
      end
      
      title = video_info_hash["title"]
      length_s = video_info_hash["length_seconds"]
      token = video_info_hash["token"]

      #for the formats, see: http://en.wikipedia.org/wiki/YouTube#Quality_and_codecs
      fmt_list = video_info_hash["fmt_list"].split(",")
      available_formats = fmt_list.map{|format| format.split("/").first}
      
      format_ext = {}
      format_ext["38"] = {:extension => "mp4", :name => "MP4 Highest Quality 4096x3027 (H.264, AAC)"}            
      format_ext["37"] = {:extension => "mp4", :name => "MP4 Highest Quality 1920x1080 (H.264, AAC)"}
      format_ext["22"] = {:extension => "mp4", :name => "MP4 1280x720 (H.264, AAC)"}
      format_ext["45"] = {:extension => "webm", :name => "WebM 1280x720 (VP8, Vorbis)"}
      format_ext["44"] = {:extension => "webm", :name => "WebM 854x480 (VP8, Vorbis)"}    
      format_ext["18"] = {:extension => "mp4", :name => "MP4 640x360 (H.264, AAC)"}
      format_ext["35"] = {:extension => "flv", :name => "FLV 854x480 (H.264, AAC)"}
      format_ext["34"] = {:extension => "flv", :name => "FLV 640x360 (H.264, AAC)"}
      format_ext["5"] = {:extension => "flv", :name => "FLV 400x240 (Soerenson H.263)"}
      format_ext["17"] = {:extension => "3gp", :name => "3gp"}    
      
      #since 1.8 doesn't do ordered hashes
      prefered_order = ["38","37","22","45","44","18","35","34","5","17"]
      
      selected_format = prefered_order.select{|possible_format| available_formats.include?(possible_format)}.first
      
      puts "[YOUTUBE] Title: #{title}"
      puts "[YOUTUBE] Length: #{length_s} s"
      puts "[YOUTUBE] t-parameter: #{token}"
      #best quality seems always to be firsts
      puts "[YOUTUBE] formats available: #{available_formats.inspect} (downloading format #{selected_format} -> #{format_ext[selected_format][:name]})"

      #video_info_hash.keys.sort.each{|key| puts "#{key} : #{video_info_hash[key]}" }
      download_url = video_info_hash["url_encoded_fmt_stream_map"][selected_format]
      #if download url ends with a ';' followed by a codec string remove that part because it stops URI.parse from working
      download_url = $1 if download_url =~ /(.*?);\scodecs=/
      
      redirect = PluginBase.get_location_header(download_url)
      download_url = redirect if redirect

      file_name = PluginBase.make_filename_safe(title) + "." + format_ext[selected_format][:extension]
      puts "downloading to " + file_name
      {:url => download_url, :name => file_name}
    end
  end
end
