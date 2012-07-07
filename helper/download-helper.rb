module ViddlRb
  class DownloadHelper

    class RequirementsNotMet < StandardError; end

    #viddl will attempt the first of these tools it finds on the system to download the video.
    #if the system does not have any of these tools, net/http is used instead.
    TOOLS_PRIORITY_LIST = [:wget, :curl] 

    #simple helper that will save a file from the web and save it with a progress bar
    def self.save_file(file_url, file_name, path = Dir.getwd, amount_of_tries = 6)
      trap("SIGINT") { puts "goodbye"; exit }

      file_path = File.join(path, file_name)
      unescaped_url = CGI::unescape(file_url)
      downloader = get_downloader
      success = false

      #some providers seem to flake out every now end then
      amount_of_tries.times do |i|
        case downloader
        when :wget
          puts "using wget"
          success = system("wget \"#{unescaped_url}\" -O #{file_path}")
        when :curl
          puts "using curl"
          #-L means: follow redirects, We set an agent because Vimeo seems to want one
          success = system("`curl -A 'Wget/1.8.1' -L \"#{unescaped_url}\" -o #{file_path}`")
        when :net_http
          puts "using net/http"
          success = download_and_save_file(file_name, file_path, unescaped_url)
        end

        if success
          break
        else
          puts "Download seems to have failed (retrying, attempt #{i+1}/#{amount_of_tries})"
          sleep 2
        end
      end
      success #true if download successful otherwise false
    end

    def self.download_and_save_file(file_name, full_path, download_url)
      uri = URI(download_url)
      file = File.new(full_path, "wb")
      video_size = 0

      Net::HTTP.start(uri.host, uri.port) do |http|
        http.request_get(uri.request_uri) do |res|
          video_size = res.read_header["content-length"].to_i
          
          bar = ProgressBar.new(file_name, video_size)
          bar.file_transfer_mode
          res.read_body do |segment|
            bar.inc(segment.size)
            file.write(segment)
          end
        end
      end
      print "\n"
      file.close

      download_successful?(full_path, video_size)   #because Net::HTTP.start does not throw Net exceptions
    end

    def self.get_downloader
      tool = TOOLS_PRIORITY_LIST.find { |tool| os_has?(tool) }
      #return tool if tool

      #check to see if the progressbar gem is installed
      begin
        require "progressbar"
      rescue LoadError
        raise RequirementsNotMet, 
          "curl or wget not found on your system. In this case you'll need to install the 'progressbar' gem."
      end
      :net_http
    end

    def self.download_successful?(full_file_path, file_size)
      File.exist?(full_file_path) && File.size(full_file_path) == file_size
    end
    
    #checks to see whether the os has a certain utility like wget or curl
    #`` returns the standard output of the process
    #system returns the exit code of the process
    def self.os_has?(utility)
      windows = ENV['OS'] =~ /windows/i

      unless windows # if os is not Windows
        `which #{utility}`.include?(utility)
      else
        if has_where?
          system("where /q #{utility}")   #/q is the quiet mode flag
        else
          begin   #as a fallback we just run the utility itself
            system(utility)
          rescue Errno::ENOENT
            false
          end
        end
      end
    end

    #checks if Windows has the where utility (Server 2003 and later)
    #system only return nil if the command is not found
    def self.has_where?
      !system("where /q where").nil?
    end
  end
end