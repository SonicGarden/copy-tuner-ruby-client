$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'copy_tuner_client/version'

Gem::Specification.new do |s|
  s.required_ruby_version = '>= 3.2.0'
  s.add_dependency 'i18n', '>= 0.5.0'
  s.add_dependency 'json'
  s.add_dependency 'nokogiri'
  # TODO: 最終的にはMCP機能は copy_tuner_client-mcp 的なgemに抽出して本番で不要な依存は消したい
  s.add_dependency 'mcp', '~> 0.1.0'
  s.add_development_dependency 'rails', '~> 7.1'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'sham_rack'
  s.add_development_dependency 'sinatra'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'thin'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'yard'
  s.authors = ['SonicGarden']
  s.email = 'info@sonicgarden.jp'
  s.files = `git ls-files`.split("\n")
  s.bindir = "exe"
  s.executables = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.homepage = 'https://github.com/SonicGarden/copy-tuner-ruby-client'
  s.name = 'copy_tuner_client'
  s.platform = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.summary = 'Client for the CopyTuner copy management service'
  s.version = CopyTunerClient::VERSION
  s.metadata['rubygems_mfa_required'] = 'true'
end
