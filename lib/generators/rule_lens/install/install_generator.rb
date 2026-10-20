# frozen_string_literal: true

require "rails/generators/base"

module RuleLens
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Create editable Pundit cases and a test-environment capture script."
      class_option :scope, type: :boolean, default: false, desc: "Create separate Scope visibility capture files."

      def create_capture_files
        if options[:scope]
          copy_file "scope_cases.rb", "config/rule_lens_scope_cases.rb", skip: true, force: false
          copy_file "scope_capture.rb", "script/rule_lens_scope_capture.rb", skip: true, force: false
        else
          copy_file "cases.rb", "config/rule_lens_cases.rb", skip: true, force: false
          copy_file "capture.rb", "script/rule_lens_capture.rb", skip: true, force: false
        end
      end

      def explain_next_steps
        if options[:scope]
          say "Edit config/rule_lens_scope_cases.rb with your Scope class, stable record keys and test cases."
          say "Then run: ruby script/rule_lens_scope_capture.rb scope-before.json YOUR_REVISION"
          say "Compare captures with: rule_lens scope-compare BEFORE.json AFTER.json --output scope-review.html"
        else
          say "Edit config/rule_lens_cases.rb with your policy and reproducible test cases."
          say "Then run: ruby script/rule_lens_capture.rb before.json YOUR_REVISION"
        end
        say "The script only runs in test, rejects DATABASE_URL, and never prepares or resets your database."
        say "First comparison guide: https://github.com/johnfreeman13592-lab/rule_lens/blob/main/docs/first-comparison.md"
        say "Existing files are skipped, even with --force. To update a customized script, review the template diff and merge it manually."
      end
    end
  end
end
