
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "citrine/version"

Gem::Specification.new do |spec|
  spec.name          = "citrine"
  spec.version       = Citrine::VERSION
  spec.authors       = ["Chi Man Lei"]
  spec.email         = ["rubyist.chi@gmail.com"]

  spec.summary       = %q{Actor-based service api framework}
  spec.description   = %q{Actor-based service api framework}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
     f.match(%r{^(test|spec|features|examples)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.5.0"
  spec.add_runtime_dependency "celluloid", "= 0.17.4"
  spec.add_runtime_dependency "reel", ">= 0.6.1"
  spec.add_runtime_dependency "sequel", ">= 5.8.0"
  spec.add_runtime_dependency "http", "~> 4.0.0"
  spec.add_runtime_dependency "sinatra", ">= 2.0.1"
  spec.add_runtime_dependency "sinatra-contrib", ">=2.0.1"
  spec.add_runtime_dependency "rack", ">= 2.0.5"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
