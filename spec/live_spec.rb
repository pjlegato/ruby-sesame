# This specifies the behavior when a live Sesame 2.0 server is running
# on localhost:8080 with the default configuration.
#
# N.B. It will fail if that is not the case, through no fault of its own.
#

require File.join(File.dirname(__FILE__), *%w[spec_helper])

URL = "http://localhost:8080/openrdf-sesame"

describe "Live Ruby-Sesame tests (**** N.B. these will fail unless you have a properly configured Sesame server running!!)" do
  it_should_behave_like "shared RubySesame specs"

  it "should be able to query the Sesame server's version number" do
    RubySesame::Server.new(URL).protocol_version.should == 4
  end

  it "should be able to get a list of repositories" do
    puts RubySesame::Server.new(URL).repositories.inspect
  end

  it "should auto-query upon initialization if told to do so" do
    server = nil
    lambda { server = RubySesame::Server.new(URL, true) }.should_not raise_error
    server.protocol_version.should == 4
  end

end
