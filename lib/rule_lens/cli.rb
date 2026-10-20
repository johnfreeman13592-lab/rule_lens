# frozen_string_literal: true

require "optparse"
require_relative "snapshots"
require_relative "html_report"
require_relative "scope_snapshots"
require_relative "scope_html_report"

module RuleLens
  module CLI
    def self.run(argv, out: $stdout, err: $stderr)
      arguments = argv.dup
      usage = "Usage: rule_lens (compare|scope-compare) BEFORE.json AFTER.json --output REPORT.html [--fail-on-change]"
      if arguments == ["--help"] || arguments == ["-h"]
        out.puts usage
        return 0
      end
      command = arguments.shift
      raise ArgumentError, usage unless %w[compare scope-compare].include?(command)

      options = {}
      parser = OptionParser.new do |opts|
        opts.on("--output PATH") { |path| options[:output] = path }
        opts.on("--fail-on-change") { options[:fail] = true }
      end
      parser.parse!(arguments)
      raise ArgumentError, usage unless arguments.size == 2 && options[:output]

      snapshots, renderer, unit = command == "scope-compare" ? [ScopeSnapshots, ScopeHTMLReport, "scope"] : [Snapshots, HTMLReport, "permission"]
      report = snapshots.compare(before: snapshots::Snapshot.load(arguments[0]), after: snapshots::Snapshot.load(arguments[1]))
      File.open(options[:output], "wx:UTF-8") { |file| file.write(renderer.render(report)) }
      out.puts "#{report.changes.size} #{unit} changes, #{report.errors.size} errors, #{report.rows.size} cases. Report: #{options[:output]}"
      return 2 if report.incomplete? || report.rows.empty?

      options[:fail] && report.attention? ? 1 : 0
    rescue ArgumentError, SystemCallError => error
      err.puts "Error: #{error.message}"
      2
    end
  end
end
