module ViddlRb
  class DownloadHelper

    #usually not called directly
    def self.fetch_file(uri)
    begin
      require "progressbar" #http://github.com/nex3/ruby-progressbar
    rescue LoadError
      puts "ERROR: You don't seem to have curl or wget on your system. In this case you'll need to install the 'progressbar' gem."
      exit
    end
      progress_bar = nil 
      open(uri, :proxy => nil,
        :content_length_proc => lambda { |length|
          if length && 0 < length
            progress_bar = ProgressBar.new(uri.to_s, length)
            progress_bar.file_transfer_mode   #to show download speed and file size
          end 
        },
        :progress_proc => lambda { |progress|
          progress_bar.set(progress) if progress_bar
        }) {|file| return file.read}        
    end
    
    #simple helper that will save a file from the web and save it with a progress bar
    def self.save_file(file_uri, file_name, path = Dir.getwd, amount_of_tries = 6)
      trap("SIGINT") { puts "goodbye"; exit }

      file_path = File.join(path, file_name)
      unescaped_uri = CGI::unescape(file_uri)
      #Some providers seem to flake out every now end then
      amount_of_tries.times do |i|
        if os_has?("wget")
          puts "using wget"
          `wget \"#{unescaped_uri}\" -O #{file_path}`
        elsif os_has?("curl")
          puts "using curl"
          #-L means: follow redirects, We set an agent because Vimeo seems to want one
          `curl -A 'Wget/1.8.1' -L \"#{unescaped_uri}\" -o #{file_path}`
        else
         puts "using net/http"
          open(file_path, 'wb') { |file|          
            file.write(fetch_file(unescaped_uri)); puts
          }
        end  
        #we were successful, we're outta here
        if $? == 0
          break
        else
          puts "Download seems to have failed (retrying, attempt #{i+1}/#{amount_of_tries})"
          sleep 2
        end
      end    
      $? == 0
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