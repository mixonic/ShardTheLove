require 'rake'
require 'spec/rake/spectask'

Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList['spec/*_spec.rb']
  t.ruby_opts = ['-v']
  t.spec_opts = ['--colour', '--format profile', '--loadby mtime', '--timeout 6', '--reverse']
  t.verbose = true
  t.warning = true
end

task :default  => :spec

