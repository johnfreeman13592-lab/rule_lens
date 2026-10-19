# frozen_string_literal: true

require "rails/generators/base"

module RuleLens
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Create editable Pundit cases and a test-environment capture script."

      def create_capture_files
        copy_file "cases.rb", "config/rule_lens_cases.rb", skip: true, force: false
        copy_file "capture.rb", "script/rule_lens_capture.rb", skip: true, force: false
      end

      def explain_next_steps
        say "Edit config/rule_lens_cases.rb with your policy and reproducible test cases."
        say "Then run: ruby script/rule_lens_capture.rb before.json YOUR_REVISION"
        say "The script only runs in test, rejects DATABASE_URL, and never prepares or resets your database."
      end
    end
  end
end
