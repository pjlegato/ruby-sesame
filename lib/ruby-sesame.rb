require 'curb'
require 'json'

module RubySesame
  ## MIME types for result format to be sent by server.
  RESULT_TYPES = {
    ## MIME types for variable binding formats
    :XML => "application/sparql-results+xml",
    :JSON => "application/sparql-results+json",
    :binary => "application/x-binary-rdf-results-table",

    ## MIME types for RDF formats
    :RDFXML => "application/rdf+xml",
    :NTriples => "text/plain",
    :Turtle => "application/x-turtle",
    :N3 => "text/rdf+n3",
    :TriX => "application/trix",
    :TriG => "application/x-trig",

    ## MIME types for boolean result formats
    # :XML type is valid here, too.
    :PlainTextBoolean => "text/boolean"
  }


  class Server
    attr_reader :url, :repositories

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
      easy.headers["Accept"] = RESULT_TYPES[:JSON]
      easy.url = @url + "repositories"
      easy.http_get
      @repositories = JSON.parse(easy.body_str)["results"]["bindings"].map{|x| Repository.new(self, x) }
    end

  end # class Server

  class Repository
    attr_reader :server, :uri, :id, :title, :writable, :readable

    def initialize(server, attrs)
      @server = server
      @uri = attrs["uri"]["value"]
      @id = attrs["id"]["value"]
      @title = attrs["title"]["value"]
      @writable = attrs["writable"]["value"] == "true"
      @readable = attrs["readable"]["value"] == "true"
    end

    #
    # The valid result_types depend on what type of query you're
    # doing: "Relevant values are the MIME types of supported RDF
    # formats for graph queries, the MIME types of supported variable
    # binding formats for tuple queries, and the MIME types of
    # supported boolean result formats for boolean queries."
    #
    # variable_bindings should be nil or a Hash. If present, it will
    # be used to bind variables outside the actual query. Keys are
    # variable names and values are N-Triples encoded RDF values.
    #
    def query(query, result_type=RESULT_TYPES[:JSON], method=:get, query_language="sparql", infer=true, variable_bindings=nil)
      easy = Curl::Easy.new
      easy.headers["Accept"] = result_type

      if method == :get
        easy.url = (self.uri + "?" +
                    "query=#{ easy.escape(query) }&"+
                    "queryLn=#{ easy.escape(query_language) }&" +
                    (!infer ? "infer=false&" : "" ) +
                    if variable_bindings
                      variable_bindings.keys.map {|name|
                        "$<#{ easy.escape(name) }>=#{ easy.escape(variable_bindings[name]) }"
                      }.join("&")
                    else
                      ""
                    end
                    ).chop


        easy.http_get

      else # POST.
        easy.url = self.server.url + self.uri
        raise Exception.new("Not implemented yet")
      end

      easy.body_str
    end # query


  end # class Repository
end
