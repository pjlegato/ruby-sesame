require File.join(File.dirname(__FILE__), *%w[spec_helper])

shared_examples_for "shared RubySesame specs" do

  it "should initialize cleanly" do
    lambda { RubySesame::Server.new("http://foo.bar:12345") }.should_not raise_error
  end

  it "should auto-add a trailing slash to a given server URL if it doesn't have one" do
    server = RubySesame::Server.new("http://foo.bar:123")
    server.url.should == "http://foo.bar:123/"

    server = RubySesame::Server.new("http://foo.bar:987/")
    server.url.should == "http://foo.bar:987/"
  end

end
