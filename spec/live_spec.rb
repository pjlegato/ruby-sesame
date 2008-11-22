# This specifies the behavior when a live Sesame 2.0 server is running
# on localhost:8080 with the default configuration.
#
# N.B. It will fail if that is not the case, through no fault of its own.
#

require File.join(File.dirname(__FILE__), *%w[spec_helper])

require 'xml/libxml'

URL = "http://localhost:8080/openrdf-sesame"
TUPLE_QUERY = <<END
PREFIX rdf:<http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sys:<http://www.openrdf.org/config/repository#>
SELECT ?id ?p ?o
WHERE {
 ?id sys:repositoryID "SYSTEM" .
 ?id ?p ?o .
}
END

GRAPH_QUERY = <<END
PREFIX rdf:<http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sys:<http://www.openrdf.org/config/repository#>
DESCRIBE ?id
WHERE {
 ?id sys:repositoryID "SYSTEM" .
}
END

describe "Live Ruby-Sesame tests (**** N.B. these will fail unless you have a properly configured Sesame server running on localhost!)" do
  it_should_behave_like "shared RubySesame specs"

  before do
    @server = RubySesame::Server.new(URL)
  end

  it "should be able to query the Sesame server's version number" do
    @server.protocol_version.should == 4
  end

  it "should be able to get a list of repositories" do
    repos = nil
    lambda { repos = @server.repositories }.should_not raise_error
    repos.each {|r| r.class.should == RubySesame::Repository }
    repos.select {|r| r.title == "System configuration repository" }.size.should == 1
    repos.select {|r| r.id == "SYSTEM" }.size.should == 1
  end

  it "should auto-query upon initialization if told to do so" do
    server = nil
    lambda { server = RubySesame::Server.new(URL, true) }.should_not raise_error
    server.protocol_version.should == 4
  end

  it "should be able to run a GET JSON tuple query on the System repository" do
    repo = @server.repository("SYSTEM")
    result = nil

    lambda { result = JSON.parse(repo.query(TUPLE_QUERY)) }.should_not raise_error
    result["head"].should == { "vars" => ["id", "p", "o"] }
    result["results"]["bindings"].size.should == 4

    result["results"]["bindings"].select{|x| x["o"]["value"] == "http://www.openrdf.org/config/repository#Repository"}.first["p"]["value"].should == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    result["results"]["bindings"].select{|x| x["o"]["value"] == "SYSTEM"}.first["p"]["value"].should == "http://www.openrdf.org/config/repository#repositoryID"
    result["results"]["bindings"].select{|x| x["o"]["value"] == "System configuration repository"}.first["p"]["value"].should == "http://www.w3.org/2000/01/rdf-schema#label"
  end

  ## TODO: figure out how to verify that this actually does a POST and not a GET.
  it "should be able to run a POST JSON tuple query on the System repository" do
    repo = @server.repository("SYSTEM")
    result = nil

    lambda { result = JSON.parse(repo.query(TUPLE_QUERY, :method => :post)) }.should_not raise_error
    result["head"].should == { "vars" => ["id", "p", "o"] }
    result["results"]["bindings"].size.should == 4

    result["results"]["bindings"].select{|x| x["o"]["value"] == "http://www.openrdf.org/config/repository#Repository"}.first["p"]["value"].should == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    result["results"]["bindings"].select{|x| x["o"]["value"] == "SYSTEM"}.first["p"]["value"].should == "http://www.openrdf.org/config/repository#repositoryID"
    result["results"]["bindings"].select{|x| x["o"]["value"] == "System configuration repository"}.first["p"]["value"].should == "http://www.w3.org/2000/01/rdf-schema#label"
  end

  it "should be able to get XML tuple results from the System repository" do
    repo = @server.repository("SYSTEM")
    result = nil
    lambda { result = repo.query(TUPLE_QUERY, :result_type => RubySesame::RESULT_TYPES[:XML]) }.should_not raise_error

    xml = nil
    lambda { xml = XML::Parser.string(result).parse }
  end

  it "should be able to get binary tuple results from the System repository" do
    repo = @server.repository("SYSTEM")
    result = nil
    lambda { result = repo.query(TUPLE_QUERY, :result_type => RubySesame::RESULT_TYPES[:binary]) }.should_not raise_error

    result[0..3].should == "BRTR"
  end

  it "should be able to get RDFXML results for a graph query" do
    repo = @server.repository("SYSTEM")
    result = nil
    lambda { result = repo.query(GRAPH_QUERY, :result_type => RubySesame::RESULT_TYPES[:RDFXML]) }.should_not raise_error

    xml = nil
    lambda { xml = XML::Parser.string(result).parse }.should_not raise_error
  end

  it "should be able to get NTriples results for a graph query" do
    repo = @server.repository("SYSTEM")
    result = nil
    lambda { result = repo.query(GRAPH_QUERY, :result_type => RubySesame::RESULT_TYPES[:NTriples]) }.should_not raise_error
  end

  it "should be able to get Turtle results for a graph query" do
    repo = @server.repository("SYSTEM")
    result = nil
    lambda { result = repo.query(GRAPH_QUERY, :result_type => RubySesame::RESULT_TYPES[:Turtle]) }.should_not raise_error
  end

  it "should be able to get N3 results for a graph query" do
    repo = @server.repository("SYSTEM")
    result = nil
    lambda { result = repo.query(GRAPH_QUERY, :result_type => RubySesame::RESULT_TYPES[:N3]) }.should_not raise_error
  end

  it "should be able to get TriX results for a graph query" do
    repo = @server.repository("SYSTEM")
    result = nil
    lambda { result = repo.query(GRAPH_QUERY, :result_type => RubySesame::RESULT_TYPES[:TriX]) }.should_not raise_error
  end

  it "should be able to get TriG results for a graph query" do
    repo = @server.repository("SYSTEM")
    result = nil
    lambda { result = repo.query(GRAPH_QUERY, :result_type => RubySesame::RESULT_TYPES[:TriG]) }.should_not raise_error
  end


end
