module ViddlRb
  class PluginBase
    #some static stuff
    class << self
      attr_accessor :io
      attr_reader   :registered_plugins
    end

    #all calls to #puts, #print and #p from any plugin instance will be redirected to this object 
    @io = $stdout
    @registered_plugins = []

    #if you inherit from this class, the child gets added to the "registered plugins" array
    def self.inherited(child)
      PluginBase.registered_plugins << child
    end

    #takes a string a returns a new string that is file name safe
    #deletes \"' and replaces anything else that is not a digit or letter with _
    def self.make_filename_safe(string)
      string.delete("\"'").gsub(/[^\d\w]/, '_')
    end

    #takes an url and makes a get request to it (without reading the body) and the return the headers as a hash
    def self.get_http_headers(url)
      uri = URI(url)

      Net::HTTP.start(uri.host, uri.port) do |http|
        http.request_get(uri.request_uri) do |response|
          return response.to_hash
        end
      end
    end

    #the following methods redirects the Kernel printing methods (except #p) to the
    #PluginBase IO object. this is because sometimes we don't want plugins to
    #write to something else than $stdout

    def self.puts(*objects)
      PluginBase.io.puts(*objects)
      nil
    end

    def self.print(*objects)
      PluginBase.io.print(*objects)
      nil
    end

    def self.putc(int)
      PluginBase.io.putc(int)
      nil
    end

    def self.printf(string, *objects)
      if string.is_a?(IO) || string.is_a?(StringIO)
        super(string, *objects)  # so we don't redirect the printf that prints to a separate IO object
      else
        PluginBase.io.printf(string, *objects)
      end
      nil
    end
  end
end
