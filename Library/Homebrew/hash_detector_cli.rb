#!/usr/bin/env ruby
# typed: false
# frozen_string_literal: true

require_relative "hash_detector"

module HashDetector
  # Command-line interface for the hash detection system.
  module CLI
    module_function

    USAGE = <<~TEXT
      Usage: ruby hash_detector_cli.rb [OPTIONS] [HASH ...]

      Identify cryptographic and non-cryptographic hash algorithms from their output.

      Options:
        -f, --file FILE    Read hashes from a file (one per line)
        -j, --json         Output results as JSON
        -c, --category CAT Filter results by category
        -l, --list         List all supported hash algorithms
        -s, --stats        Show statistics about detected hashes
        -h, --help         Show this help message

      Categories:
        message_digest, sha, sha3, blake, checksum, non_cryptographic,
        password, windows, database, cryptographic, ripemd

      Examples:
        ruby hash_detector_cli.rb d41d8cd98f00b204e9800998ecf8427e
        ruby hash_detector_cli.rb -f hashes.txt --json
        ruby hash_detector_cli.rb --list
        echo "5d41402abc4b2a76b9719d911017c592" | ruby hash_detector_cli.rb
    TEXT

    def run(argv = ARGV)
      options = parse_options(argv)

      if options[:help]
        puts USAGE
        return
      end

      if options[:list]
        list_algorithms(options)
        return
      end

      hashes = collect_hashes(argv, options)

      if hashes.empty?
        $stderr.puts "Error: No hash input provided. Use -h for help."
        exit 1
      end

      results = HashDetector::Detector.identify_many(hashes)

      if options[:stats]
        print_stats(results)
      elsif options[:json]
        print_json(results, options)
      else
        print_text(results, options)
      end
    end

    def parse_options(argv)
      options = {}
      i = 0
      while i < argv.length
        case argv[i]
        when "-h", "--help"
          options[:help] = true
        when "-f", "--file"
          i += 1
          options[:file] = argv[i]
        when "-j", "--json"
          options[:json] = true
        when "-c", "--category"
          i += 1
          options[:category] = argv[i]&.to_sym
        when "-l", "--list"
          options[:list] = true
        when "-s", "--stats"
          options[:stats] = true
        end
        i += 1
      end
      options
    end

    def collect_hashes(argv, options)
      hashes = []

      # From positional arguments (skip flags and their values).
      skip_next = false
      argv.each do |arg|
        if skip_next
          skip_next = false
          next
        end
        if ["-f", "--file", "-c", "--category"].include?(arg)
          skip_next = true
          next
        end
        next if arg.start_with?("-")

        hashes << arg
      end

      # From file.
      if options[:file]
        if File.exist?(options[:file])
          File.readlines(options[:file]).each do |line|
            stripped = line.strip
            hashes << stripped unless stripped.empty? || stripped.start_with?("#")
          end
        else
          $stderr.puts "Error: File not found: #{options[:file]}"
          exit 1
        end
      end

      # From stdin if no other input and stdin is not a terminal.
      if hashes.empty? && !$stdin.tty?
        $stdin.each_line do |line|
          stripped = line.strip
          hashes << stripped unless stripped.empty? || stripped.start_with?("#")
        end
      end

      hashes
    end

    def list_algorithms(options)
      patterns = HashDetector::Patterns::DEFINITIONS
      if options[:category]
        patterns = patterns.select { |p| p.category == options[:category] }
      end

      grouped = patterns.group_by(&:category)
      grouped.each do |category, pats|
        puts "#{category}"
        puts "-" * 40
        pats.each do |p|
          len_str = p.length ? "#{p.length} hex chars" : "variable length"
          puts "  #{p.name.ljust(30)} #{len_str}"
        end
        puts
      end
      puts "Total: #{patterns.size} algorithms"
    end

    def print_text(results, options)
      results.each do |input, matches|
        filtered = filter_by_category(matches, options[:category])
        puts HashDetector::Detector.report(input) if filtered.length == matches.length
        next if filtered.length == matches.length

        puts "Hash:    #{input}"
        puts "Length:  #{input.strip.length} characters"
        puts ""
        if filtered.empty?
          puts "No matching algorithms in category '#{options[:category]}'."
        else
          puts "Possible algorithms (#{filtered.size} candidates, filtered by #{options[:category]}):"
          puts "-" * 60
          filtered.each_with_index do |m, i|
            puts "  #{i + 1}. #{m}"
          end
        end
        puts "=" * 60
      end
    end

    def print_json(results, options)
      require "json"
      output = results.map do |input, matches|
        filtered = filter_by_category(matches, options[:category])
        {
          input:      input,
          length:     input.strip.length,
          candidates: filtered.map(&:to_h),
        }
      end
      puts JSON.pretty_generate(output)
    end

    def print_stats(results)
      total = results.size
      identified = results.count { |_, matches| !matches.empty? }
      unidentified = total - identified

      algo_counts = Hash.new(0)
      category_counts = Hash.new(0)
      confidence_counts = Hash.new(0)

      results.each_value do |matches|
        matches.each do |m|
          algo_counts[m.algorithm] += 1
          category_counts[m.category] += 1
          confidence_counts[m.confidence] += 1
        end
      end

      puts "Hash Detection Statistics"
      puts "=" * 40
      puts "Total hashes analyzed:  #{total}"
      puts "Identified:             #{identified}"
      puts "Unidentified:           #{unidentified}"
      puts
      puts "Top algorithm matches:"
      puts "-" * 40
      algo_counts.sort_by { |_, c| -c }.first(10).each do |algo, count|
        puts "  #{algo.ljust(30)} #{count}"
      end
      puts
      puts "By category:"
      puts "-" * 40
      category_counts.sort_by { |_, c| -c }.each do |cat, count|
        puts "  #{cat.to_s.ljust(30)} #{count}"
      end
      puts
      puts "By confidence:"
      puts "-" * 40
      confidence_counts.sort_by { |_, c| -c }.each do |conf, count|
        puts "  #{conf.to_s.ljust(30)} #{count}"
      end
    end

    def filter_by_category(matches, category)
      return matches unless category

      matches.select { |m| m.category == category }
    end
  end
end

# Run if invoked directly.
HashDetector::CLI.run if __FILE__ == $PROGRAM_NAME
