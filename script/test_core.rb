# frozen_string_literal: true

# Keep Bundler in this process: bundle exec can corrupt Japanese Windows paths
# when it re-launches Ruby. Resolve paths from the script rather than shell args.
ENV["BUNDLE_GEMFILE"] = File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
Dir[File.expand_path("../test/**/*_test.rb", __dir__)].sort.each { |path| require path }
