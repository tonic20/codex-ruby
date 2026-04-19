# frozen_string_literal: true

require_relative "lib/codex_sdk/version"

Gem::Specification.new do |spec|
  spec.name = "codex-ruby"
  spec.version = CodexSDK::VERSION
  spec.authors = ["Anton Kopylov"]
  spec.email = ["anton@tonic20.com"]

  spec.summary = "Ruby SDK for the Codex CLI"
  spec.description = "A Ruby client for the Codex CLI, providing subprocess management, " \
                     "JSONL event parsing, and a clean API for building AI-powered applications."
  spec.homepage = "https://github.com/tonic20/codex-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
end
