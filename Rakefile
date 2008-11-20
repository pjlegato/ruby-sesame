require 'rubygems'
require 'spec/rake/spectask'

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
