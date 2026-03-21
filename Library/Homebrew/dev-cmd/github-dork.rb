# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "utils/github"

module Homebrew
  module DevCmd
    class GithubDork < AbstractCommand
      cmd_args do
        usage_banner "`github-dork` [<options>] <query>"
        description <<~EOS
          Search GitHub using advanced search queries (dork queries) for code, repositories, or commits.
          Useful for finding specific patterns across Homebrew taps and related repositories.

          The <query> supports GitHub search syntax qualifiers such as:
            `extension:rb` - file extension filter
            `language:ruby` - programming language filter
            `org:Homebrew` - organisation filter
            `repo:Homebrew/homebrew-core` - repository filter
            `filename:Formula` - filename filter
            `path:Formula/` - path filter
        EOS
        switch "--code",
               description: "Search for code matching the query (default)."
        switch "--repos", "--repositories",
               description: "Search for repositories matching the query."
        switch "--commits",
               description: "Search for commits matching the query."

        conflicts "--code", "--repos", "--commits"

        named_args :text, min: 1
      end

      sig { override.void }
      def run
        odie "Cannot use GitHub API as `$HOMEBREW_NO_GITHUB_API` is set!" if Homebrew::EnvConfig.no_github_api?

        query = args.named.join(" ")
        search_type = if args.repos?
          "repositories"
        elsif args.commits?
          "commits"
        else
          "code"
        end

        results = GitHub.search(search_type, query)
        items = results.fetch("items", [])
        total_count = results.fetch("total_count", 0)

        if items.empty?
          puts "No #{search_type} results found for #{query.inspect}."
          return
        end

        ohai "#{total_count} #{search_type} result#{"s" if total_count != 1} for #{query.inspect} " \
             "(showing #{items.size}):"
        puts

        case search_type
        when "code"
          print_code_results(items)
        when "repositories"
          print_repository_results(items)
        when "commits"
          print_commit_results(items)
        end
      end

      private

      sig { params(items: T::Array[T::Hash[String, T.untyped]]).void }
      def print_code_results(items)
        items.each do |item|
          repo = item.fetch("repository", {})
          puts "#{Tty.bold}#{repo["full_name"]}#{Tty.reset} — #{item["path"]}"
          puts "  #{item["html_url"]}"
          puts
        end
      end

      sig { params(items: T::Array[T::Hash[String, T.untyped]]).void }
      def print_repository_results(items)
        items.each do |item|
          description = item["description"].presence
          stars = item.fetch("stargazers_count", 0)
          puts "#{Tty.bold}#{item["full_name"]}#{Tty.reset} (★#{stars})"
          puts "  #{description}" if description
          puts "  #{item["html_url"]}"
          puts
        end
      end

      sig { params(items: T::Array[T::Hash[String, T.untyped]]).void }
      def print_commit_results(items)
        items.each do |item|
          commit = item.fetch("commit", {})
          author = commit.dig("author", "name") || "Unknown"
          message = commit.fetch("message", "").lines.first&.strip || ""
          puts "#{Tty.bold}#{item["sha"][0, 7]}#{Tty.reset} — #{author}: #{message}"
          puts "  #{item["html_url"]}"
          puts
        end
      end
    end
  end
end
