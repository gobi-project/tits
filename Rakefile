require 'rake/testtask'

task :default => [:build, :install]

desc "Run tests"
Rake::TestTask.new do |t|
  t.libs.push 'lib'
  t.libs.push 'specs'
  t.test_files = FileList['specs/*_spec.rb']
  t.verbose = true
  ENV['RAILS_ENV'] ||= 'test'
end

desc "Build gem"
task :build do
  sh "gem build tits.gemspec"
end

desc "Install gem"
task :install do
  sh "gem install ./tits-*.gem"
end

desc "Uninstall gem"
task :uninstall do
  sh "gem uninstall tits"
end

desc "Clean gem"
task :clean do
  begin
    sh "rm ./tits-*.gem"
  rescue
  end
  begin
    sh "rm -R ./.yardoc"
  rescue
  end
  begin
    sh "rm -R ./doc"
  rescue
  end
end

desc "Bundle install"
task :bundle do
  sh "bundle install"
end

desc "Create documentation"
task :doc do
  sh "yardoc"
end

import 'tits_delete.rake'
