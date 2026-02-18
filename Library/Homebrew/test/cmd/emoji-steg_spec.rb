# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "cmd/emoji-steg"

RSpec.describe Homebrew::Cmd::EmojiSteg do
  it_behaves_like "parseable arguments"

  it "encodes a secret message into emojis", :integration_test do
    expect { brew "emoji-steg", "--encode", "hello" }
      .to output(/.*/).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end

  it "roundtrips encode and decode", :integration_test do
    encoded = `#{HOMEBREW_BREW_FILE} emoji-steg --encode hello`.chomp
    expect { brew "emoji-steg", "--decode", encoded }
      .to output("hello\n").to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end

  it "errors without --encode or --decode", :integration_test do
    expect { brew "emoji-steg", "hello" }
      .to output(/Must specify either --encode or --decode/).to_stderr
      .and be_a_failure
  end
end
