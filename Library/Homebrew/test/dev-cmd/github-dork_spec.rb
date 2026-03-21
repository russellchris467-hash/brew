# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/github-dork"

RSpec.describe Homebrew::DevCmd::GithubDork do
  it_behaves_like "parseable arguments"
end
