require 'rubygems'
require 'hoe'
require 'lib/ruby-sesame'
require 'spec/rake/spectask'

Hoe.new('ruby-sesame', RubySesame::Version) do |p|
  p.rubyforge_name = 'ruby-sesame'
  p.author = 'Paul Legato'
  p.summary = 'A Ruby interface to OpenRDF.org\'s Sesame RDF triple store'
  p.email = 'pjlegato at gmail dot com'
  p.url = 'http://ruby-sesame.rubyforge.org'
end


desc "Run all specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList["spec/*_spec.rb"].sort
  t.spec_opts = ["--options", "spec/spec.opts"]
end

desc "Run all specs and get coverage statistics"
Spec::Rake::SpecTask.new('coverage') do |t|
  t.spec_opts = ["--options", "spec/spec.opts"]
  t.spec_files = FileList["spec/*_spec.rb"].sort
  t.rcov_opts = ["--exclude", "spec", "--exclude", "gems"]
  t.rcov = true
end

task :default => :spec
