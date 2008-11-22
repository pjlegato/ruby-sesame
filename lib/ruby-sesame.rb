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

    # Get a Repository by id. Returns the first repository if there is more than one.
    def repository(id)
      self.repositories.select {|r| r.id == id}.first
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
    def query(query, options={})
      options = {
        :result_type => RESULT_TYPES[:JSON],
        :method => :get,
        :query_language => "sparql",
        :infer => true,
        :variable_bindings => nil
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

        field.push("infer=false") unless options[:infer]

        options[:variable_bindings].keys.map {|name|
          field.push("$<#{ easy.escape(name) }>=#{ easy.escape(options[:variable_bindings][name]) }")
        } if options[:variable_bindings]

        easy.http_post(fields)
      end

      easy.body_str
    end # query

    # Perform REST operations on statements in the repository. (See also the convenience method wrappers.)
    #
    # method is one of GET, PUT, DELETE, or POST.
    #
    # N.B. if unqualified with 1 or more options, this will return/operate on _all_ statements in the repository.
    #
    # Options:
    #     * 'subj' (optional): Restricts a GET or DELETE operation to statements with the specified N-Triples encoded resource as subject.
    #     * 'pred' (optional): Restricts a GET or DELETE operation to statements with the specified N-Triples encoded URI as predicate.
    #     * 'obj' (optional): Restricts a GET or DELETE operation to statements with the specified N-Triples encoded value as object.
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
    #     * 'baseURI' (optional): Specifies the base URI to resolve
    #       any relative URIs found in uploaded data against. This
    #       parameter only applies to the PUT and POST method.
    #
    def statements(method, options={})
      raise Exception.new("Not implemented yet.")
    end

  end # class Repository
end
