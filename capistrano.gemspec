$LOAD_PATH.push File.expand_path("lib", __dir__)
require "capistrano/version"

Gem::Specification.new do |spec|
  spec.name = "capistrano"
  spec.version = Capistrano::Version.to_s
  spec.platform = Gem::Platform::RUBY
  spec.authors = ["Jamis Buck", "Lee Hambley"]
  spec.email = ["jamis@jamisbuck.org", "lee.hambley@gmail.com"]
  spec.homepage = "http://github.com/capistrano/capistrano"
  spec.summary = "Capistrano - Welcome to easy deployment with Ruby over SSH"
  spec.description = "Capistrano is a utility and framework for executing commands on a remote machine, via SSH."
  spec.files = `git ls-files`.split("\n")
  spec.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  spec.executables = `git ls-files -- bin/*`.split("\n").map { |file| File.basename(file) }
  spec.require_paths = ["lib"]
  spec.extra_rdoc_files = [
    "README.md"
  ]

  spec.add_dependency 'highline', '>= 0'
  spec.add_dependency 'net-ssh', '>= 2.0.14'
  spec.add_dependency 'net-sftp', '>= 2.0.0'
  spec.add_dependency 'net-scp', '>= 1.0.0'
end
