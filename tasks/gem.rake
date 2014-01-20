require 'rubygems/package_task'
require_relative '../lib/rupnp.rb'

spec = Gem::Specification.new do |s|
  s.name = 'rupnp'
  s.version = RUPNP::VERSION
  s.summary = "RUPNP, a ruby UPnP framework"
  s.description = <<-EOF
RUPNP is a Ruby UPnP framework. For now, only control points (clients)
are supported. Devices (servers) will be later.
EOF

  s.authors << 'Sylvain Daubert'
  s.email = 'sylvain.daubert@laposte.net'
  s.homepage = 'https://github.com/sdaubert/rupnp'

  files = Dir['{spec,lib,bin,tasks}/**/*']
  files += ['README.md', 'MIT-LICENSE', 'Rakefile']
  # For now, device is not in gem.
  files -= ['lib/rupnp/device.rb', 'spec/device_spec.rb']
  s.files = files
  s.executables = ["discover"]

  s.add_dependency 'uuid', '~>2.3.0'
  s.add_dependency 'eventmachine-le', '~> 1.1.6'
  s.add_dependency 'em-http-request', '~> 1.1.1'
  s.add_dependency 'nori', '~> 2.3.0'
  s.add_dependency 'savon', '~>2.3.0'
  s.add_dependency 'pry', '~>0.9.12'

  s.add_development_dependency 'rspec', '~>2.14.0'
  s.add_development_dependency 'em-spec', '~>0.2.6'
  s.add_development_dependency 'simplecov', '~>0.8.2'
  s.add_development_dependency 'webmock', '~>1.16.1'
end


Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end
