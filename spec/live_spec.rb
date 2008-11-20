# This specifies the behavior when a live Sesame 2.0 server is running
# on localhost:8080 with the default configuration.
#
# N.B. It will fail if that is not the case, through no fault of its own.
#

require File.join(File.dirname(__FILE__), *%w[spec_helper])

URL = "http://localhost:8080/openrdf-sesame"

describe "Live Ruby-Sesame tests (**** N.B. these will fail unless you have a properly configured Sesame server running on localhost!)" do
  it_should_behave_like "shared RubySesame specs"

  it "should be able to query the Sesame server's version number" do
    RubySesame::Server.new(URL).protocol_version.should == 4
  end

  it "should be able to get a list of repositories" do
    repos = nil
    lambda { repos = RubySesame::Server.new(URL).repositories }.should_not raise_error
    repos.each {|r| r.class.should == RubySesame::Repository }
    repos.select {|r| r.title == "System configuration repository" }.size.should == 1
    repos.select {|r| r.id == "SYSTEM" }.size.should == 1
  end

  it "should auto-query upon initialization if told to do so" do
    server = nil
    lambda { server = RubySesame::Server.new(URL, true) }.should_not raise_error
    server.protocol_version.should == 4
  end

  QUERY = <<END
PREFIX rdf:<http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sys:<http://www.openrdf.org/config/repository#>
SELECT ?id ?p ?o
WHERE {
 ?id sys:repositoryID "SYSTEM" .
 ?id ?p ?o .
}
END

  it "should be able to run a GET query on the System repository" do
    repo = RubySesame::Server.new(URL, true).repositories.select {|r| r.id == "SYSTEM"}.first
    result = nil
    lambda { result = repo.query(QUERY) }.should_not raise_error
    puts result
  end

end
