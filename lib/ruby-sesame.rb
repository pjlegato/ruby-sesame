# Ruby-Sesame: a Ruby library to interact with OpenRDF.org's Sesame RDF
# framework via its REST interface.
#
# Copyright (C) 2008 Paul Legato (pjlegato at gmail dot com).
#
# This file is part of Ruby-Sesame.
#
# Ruby-Sesame is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ruby-Sesame is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ruby-Sesame.  If not, see <http://www.gnu.org/licenses/>.

require 'curb'
require 'json'

# Curb is faster, but doesn't do DELETE or PUT
require 'net/http'
require 'uri'

module RubySesame

  Version = "0.1.0"

  ## MIME types for result format to be sent by server.
  DATA_TYPES = {
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


  class SesameException < Exception
  end

  class Server
    attr_reader :url, :repositories, :logger


    # Silently eats any messages sent to it.
    class NullLogger
      def method_missing(*args)
      end
    end

    #
    # Initialize a Server object at the given URL.  Sesame uses a
    # stateless REST protocol, so this will not actually do anything
    # over the network unless query_server_information is true.  Loads
    # the protocol version and repositories available on the server if
    # it is.
    #
    # If logger is given, it should respond to #debug, #info, #warn, and #error, and do
    # something appropriate with that information.
    #
    def initialize(url, query_server_information=false, logger=NullLogger.new)
      url = url + "/" unless url[-1..-1] == "/"
      @url = url
      @logger = logger

      if query_server_information
        query_version
        query_repositories
      end

      logger.debug("Ruby-sesame initialized; connected to #{ url }")
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

    # Get a Repository by id. Returns the first repository if there is more than one.
    def repository(id)
      self.repositories.select {|r| r.id == id}.first
    end

    def query_repositories
      easy = Curl::Easy.new
      easy.headers["Accept"] = DATA_TYPES[:JSON]
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

    def logger
      @server.logger
    end


    #
    # The valid result_types depend on what type of query you're
    # doing: "Relevant values are the MIME types of supported RDF
    # formats for graph queries, the MIME types of supported variable
    # binding formats for tuple queries, and the MIME types of
    # supported boolean result formats for boolean queries."
    #
    # Options:
    #
    # * :result_type - from DATA_TYPES
    # * :method - :get or :post
    # * :query_language - "sparql", "serql", or any other query language your Sesame server supports.
    # * :infer => true or false. Defaults to true (serverside) if not specified.
    # * :variable_bindings - if given, should be a Hash. If present, it will
    #    be used to bind variables outside the actual query. Keys are
    #    variable names and values are N-Triples encoded RDF values.
    def query(query, options={})
      logger.debug("Ruby-Sesame querying:\n#{ query }\n\nOptions: #{ options.pretty_inspect }")

      options = {
        :result_type => DATA_TYPES[:JSON],
        :method => :get,
        :query_language => "sparql",
      }.merge(options)

      easy = Curl::Easy.new
      easy.headers["Accept"] = options[:result_type]

      if options[:method] == :get
        easy.url = (self.uri + "?" +
                    "query=#{ easy.escape(query) }&"+
                    "queryLn=#{ easy.escape(options[:query_language]) }&" +
                    (!options[:infer] ? "infer=false&" : "" ) +
                    if options[:variable_bindings]
                      options[:variable_bindings].keys.map {|name|
                        "$<#{ easy.escape(name) }>=#{ easy.escape(options[:variable_bindings][name]) }"
                      }.join("&")
                    else
                      ""
                    end
                    ).chop


        easy.http_get

      else # POST.
        easy.url = self.uri

        fields = ["query=#{ easy.escape(query) }",
                  "queryLn=#{ easy.escape(options[:query_language]) }"
                 ]

        fields.push("infer=false") unless options[:infer]

        options[:variable_bindings].keys.map {|name|
          field.push("$<#{ easy.escape(name) }>=#{ easy.escape(options[:variable_bindings][name]) }")
        } if options[:variable_bindings]

        easy.http_post(fields)
      end

      raise(SesameException.new(easy.body_str)) unless easy.response_code == 200

      easy.body_str
    end # query

    #
    # Returns a list of statements from the repository (i.e. performs the REST GET operation on statements in the repository.)
    #
    # N.B. if unqualified with 1 or more options, this will return _all_ statements in the repository.
    #
    # Options:
    #
    #     * result_type is the desired MIME type for results (see the DATA_TYPES constant.) Defaults to :Turtle.
    #
    #     * 'subj' (optional): Restricts the GET to statements with the specified N-Triples encoded resource as subject.
    #     * 'pred' (optional): Restricts the GET to statements with the specified N-Triples encoded URI as predicate.
    #     * 'obj' (optional): Restricts the GET to statements with the specified N-Triples encoded value as object.
    #
    #     * 'context' (optional): If specified, restricts the
    #       operation to one or more specific contexts in the
    #       repository. The value of this parameter is either an
    #       N-Triples encoded URI or bnode ID, or the special value
    #       'null' which represents all context-less statements. If
    #       multiple 'context' parameters are specified as an Array, the request
    #       will operate on the union of all specified contexts. The
    #       operation is executed on all statements that are in the
    #       repository if no context is specified.
    #
    #     * 'infer' (optional): Boolean; specifies whether inferred statements
    #       should be included in the result of GET requests. Inferred
    #       statements are included by default.
    #
    def get_statements(options={})
      options = {:result_type => DATA_TYPES[:Turtle]}.merge(options)
      easy = Curl::Easy.new
      easy.headers["Accept"] = options[:result_type]

      url = self.uri + "/statements?" + self.class.get_parameterize(options.reject{|k,v|
                                                                      ![:subj, :pred, :obj, :context, :infer].include?(k)
                                                                    })
      easy.url = url
      easy.http_get

      raise(SesameException.new(easy.body_str)) unless easy.response_code == 200

      easy.body_str
    end # get_statements

    # Delete one or more statements from the repository. Takes the same arguments as get_statements.
    #
    # If you do not set one of subj, pred, or obj in your options, it will delete ALL statements from the repository.
    # This is ordinarily not allowed. Set safety=false to delete all statements.
    #
    def delete_statements!(options={}, safety=true)

      unless !safety || options.keys.select {|x| [:subj, :pred, :obj].include?(x) }.size > 0
        raise Exception.new("You asked to delete all statements in the repository. Either give a subj/pred/obj qualifier, or set safety=false")
      end

      # We have to use net/http, because curb has not yet implemented DELETE as of this writing.

      uri = URI.parse(self.uri + "/statements?" + self.class.get_parameterize(options.reject{|k,v|
                                                                                ![:subj, :pred, :obj, :context, :infer].include?(k)
                                                                              }))
      http = Net::HTTP.start(uri.host, uri.port)
      http.delete(uri.path)
      raise(SesameException.new(easy.body_str)) unless easy.response_code == 204
    end # delete_statements!

    # Convenience method; deletes all data from the repository.
    def delete_all_statements!
      delete_statements!({}, false)
    end

    # Returns the contexts available in the repository, unprocessed.
    # Results are in JSON by default, though XML and binary are also available.
    def raw_contexts(result_format="application/sparql-results+json")
      easy = Curl::Easy.new
      easy.headers["Accept"] = result_format

      easy.url = self.uri + "/contexts"
      easy.http_get

      raise(SesameException.new(easy.body_str)) unless easy.response_code == 200

      easy.body_str
    end

    # Returns an Array of Strings, where each is the id of a context available on the server.
    def contexts
      JSON.parse(raw_contexts())["results"]["bindings"].map{|x| x["contextID"]["value"] }
    end

    # Return the namespaces available in the repository, raw and unprocessed.
    # Results are in JSON by default, though XML and binary are also available.
    def raw_namespaces(result_format="application/sparql-results+json")
      easy = Curl::Easy.new
      easy.headers["Accept"] = result_format

      easy.url = self.uri + "/namespaces"
      easy.http_get
      easy.body_str
    end

    # Returns a Hash. Keys are the prefixes, and the values are the corresponding namespaces.
    def namespaces
      ns = {}

      JSON.parse(raw_namespaces)["results"]["bindings"].each {|x|
        ns[x["prefix"]["value"]] = x["namespace"]["value"]
      }
      ns
    end

    # Gets the namespace for the given prefix.
    # Returns nil if not found.
    def namespace(prefix)
      easy = Curl::Easy.new
      easy.url = self.uri + "/namespaces/" + easy.escape(prefix)
      easy.http_get
      ns = easy.body_str
      ns =~ /^Undefined prefix:/ ? nil : ns
    end

    # Sets the given prefix to the given namespace.
    def namespace!(prefix, namespace)
      uri = URI.parse(self.uri + "/namespaces/" + URI.escape(prefix))
      http = Net::HTTP.start(uri.host, uri.port)
      http.send_request('PUT', uri.path, namespace).body
    end

    # Deletes the namespace with the given prefix.
    def delete_namespace!(prefix)
      uri = URI.parse(self.uri + "/namespaces/" + URI.escape(prefix))
      http = Net::HTTP.start(uri.host, uri.port)
      http.delete(uri.path)
    end

    # Deletes all namespaces in the repository.
    def delete_all_namespaces!
      uri = URI.parse(self.uri + "/namespaces")
      http = Net::HTTP.start(uri.host, uri.port)
      http.delete(uri.path)
    end


    # Adds new data to the repository.  The data can be an RDF document or a
    # "special purpose transaction document". I don't know what the
    # latter is.
    def add!(data, data_format=DATA_TYPES[:Turtle])
      easy = Curl::Easy.new
      easy.headers["Content-Type"] = data_format

      easy.url = self.uri + "/statements"
      easy.http_post(data)
    end # add


    # Returns the number of statements in the repository.
    def size
      easy = Curl::Easy.new
      easy.url = self.uri + "/size"
      easy.http_get
      easy.body_str.to_i
    end


    # Convert the given hash into an array of strings for a POST.
    def self.post_parameterize(hash)
      easy = Curl::Easy.new
      hash.keys.map{|key|
        easy.escape(key.to_s) + "=" + easy.escape(hash[key])
      }
    end

    # Convert the given hash into a URL paramter string for a GET.
    def self.get_parameterize(hash)
     post_parameterize(hash).join("&")
    end

  end # class Repository
end
