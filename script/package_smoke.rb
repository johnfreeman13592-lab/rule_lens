# frozen_string_literal: true

require "rubygems/package"
require "rubygems/installer"
require "tmpdir"
require "open3"
require "rbconfig"
require "json"
require "bundler"

abort "Usage: ruby script/package_smoke.rb PACKAGE.gem" unless ARGV.size == 1
package_path = File.expand_path(ARGV.first)
package = Gem::Package.new(package_path)
raise "Unexpected license" unless package.spec.license == "MIT"
raise "Private journal included" unless package.contents.grep(/development-plan|implementation-status/).empty?

Dir.mktmpdir("rule-lens-package-") do |directory|
  # Dependencies are already installed by bundle install; isolate the package
  # itself so this verifies its contents rather than loading the source tree.
  spec = Gem::Installer.at(package_path, install_dir: directory, ignore_dependencies: true, document: []).install
  environment = Bundler.unbundled_env
  environment["GEM_HOME"] = directory
  environment["GEM_PATH"] = ([directory] + Gem.path).join(File::PATH_SEPARATOR)
  executable = File.join(directory, "bin", "rule_lens")
  item = { id: "reader.update", label: "Reader edits", query: "update?", case_version: "1", status: "denied", error_class: nil }
  snapshot = { format_version: 1, suite: "package-smoke", revision: "before", data_version: "v1", context: {}, cases: [item] }
  File.write(File.join(directory, "before.json"), JSON.generate(snapshot))
  snapshot[:revision] = "after"
  item[:status] = "allowed"
  File.write(File.join(directory, "after.json"), JSON.generate(snapshot))
  out, err, status = Open3.capture3(environment, RbConfig.ruby, executable, "compare", "before.json", "after.json", "--output", "report.html", "--fail-on-change", chdir: directory, unsetenv_others: true)
  raise "Installed CLI failed: #{out}\n#{err}" unless status.exitstatus == 1
  raise "Missing installed report" unless File.read(File.join(directory, "report.html"), encoding: "UTF-8").include?("1件の権限が変化")
  puts "Installed #{spec.name} #{spec.version}: CLI and HTML report OK; MIT; private journals excluded."
end
