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

  it "should be able to make POST parameters correectly" do
    RubySesame::Repository.post_parameterize(:foo => "bar", :baz => "asdf:foo").sort.should == ["baz=asdf%3Afoo", "foo=bar"]
  end

  it "should be able to make GET parameters correectly" do
    RubySesame::Repository.get_parameterize(:foo => "bar", :baz => "asdf:foo").split("&").sort.should == ["baz=asdf%3Afoo", "foo=bar"]
  end

end
