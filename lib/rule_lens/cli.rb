# frozen_string_literal: true

require "optparse"
require_relative "snapshots"
require_relative "html_report"

module RuleLens
  module CLI
    def self.run(argv, out: $stdout, err: $stderr)
      arguments = argv.dup
      usage = "Usage: rule_lens compare BEFORE.json AFTER.json --output REPORT.html [--fail-on-change]"
      if arguments == ["--help"] || arguments == ["-h"]
        out.puts usage
        return 0
      end
      raise ArgumentError, usage unless arguments.shift == "compare"

      options = {}
      parser = OptionParser.new do |opts|
        opts.on("--output PATH") { |path| options[:output] = path }
        opts.on("--fail-on-change") { options[:fail] = true }
      end
      parser.parse!(arguments)
      raise ArgumentError, usage unless arguments.size == 2 && options[:output]

      report = Snapshots.compare(before: Snapshots::Snapshot.load(arguments[0]), after: Snapshots::Snapshot.load(arguments[1]))
      File.open(options[:output], "wx:UTF-8") { |file| file.write(HTMLReport.render(report)) }
      out.puts "#{report.changes.size} permission changes, #{report.errors.size} errors, #{report.rows.size} cases. Report: #{options[:output]}"
      return 2 if report.incomplete? || report.rows.empty?

      options[:fail] && report.attention? ? 1 : 0
    rescue ArgumentError, SystemCallError => error
      err.puts "Error: #{error.message}"
      2
    end
  end
end
