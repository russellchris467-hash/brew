# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "utils/emoji_steganography"

module Homebrew
  module Cmd
    class EmojiSteg < AbstractCommand
      cmd_args do
        description <<~EOS
          Encode or decode hidden messages in emoji strings using Unicode
          variation-selector steganography.

          In encode mode, the secret text is embedded as invisible variation
          selectors within the carrier emoji string. In decode mode, the hidden
          payload is extracted and printed.
        EOS

        switch "--encode",
               description: "Encode a secret message into an emoji carrier string."
        switch "--decode",
               description: "Decode a hidden message from an emoji string."
        flag   "--carrier=",
               description: "Emoji string used as the visible carrier (default: beer, house, coffee, package, rocket)."

        conflicts "--encode", "--decode"

        named_args :text, min: 1
      end

      sig { override.void }
      def run
        if !args.encode? && !args.decode?
          raise UsageError, "Must specify either --encode or --decode."
        end

        text = args.named.join(" ")

        if args.encode?
          carrier = args.carrier || Utils::EmojiSteganography::DEFAULT_CARRIER
          result = Utils::EmojiSteganography.encode(text, carrier:)
          puts result
        else
          result = Utils::EmojiSteganography.decode(text)
          puts result
        end
      end
    end
  end
end
