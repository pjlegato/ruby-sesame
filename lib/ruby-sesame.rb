require 'curb'
require 'json'

module RubySesame
  class Server
    attr_reader :url, :repositories

    ## Mime types for result format to be sent by server.
    XML_RESULTS = "application/sparql-results+xml"
    JSON_RESULTS = "application/sparql-results+json"
    BINARY_RESULTS = "application/x-binary-rdf-results-table"

    #
    # Initialize a Server object at the given URL.  Sesame uses a
    # stateless REST protocol, so this will not actually do anything
    # over the network unless query_server_information is true.  Loads
    # the protocol version and repositories available on the server if
    # it is.
    #
    def initialize(url, query_server_information=false)
      url = url + "/" unless url[-1..-1] == "/"
      @url = url

      if query_server_information
        query_version
      end
    end # initialize


    def query_version
      @protocol_version = Curl::Easy.http_get(@url + "protocol").body_str.to_i
    end

    def protocol_version
      @protocol_version || query_version
    end

    def repositories
      @repositories || query_repositories
    end

    def query_repositories
      easy = Curl::Easy.new
      easy.headers["Accept"] = JSON_RESULTS
      easy.url = @url + "repositories"
      easy.http_get
      @repositories = JSON.parse(easy.body_str)["results"]["bindings"].map{|x| Repository.new(x) }
    end


  end # class Server

  class Repository
    attr_reader :uri, :title, :writable, :readable

    def initialize(attrs)
      @uri = attrs["uri"]["value"]
      @title = attrs["title"]["value"]
      @writable = attrs["writable"]["value"] == "true"
      @readable = attrs["readable"]["value"] == "true"
    end

  end # class Repository
end
