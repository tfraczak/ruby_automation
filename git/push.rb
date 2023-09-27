# frozen_string_literal: true

require "dry-inflector"
require "pathname"
require "debug"
require_relative "branch"
require_relative "commit"

module Git
  class Push < Base
    BUNDLE = "bundle"
    BRAKEMAN = "brakeman"
    RUBOCOP = "rubocop"
    RSPEC = "rspec"
    YARN_LINT = "yarn lint"

    def self.call
      new.run
    end

    def self.amend_and_push
      new.amend_and_push
    end

    def self.validate_work
      new.run_checks!
    end

    def initialize
      super
      @branch = Branch.new
      @force =  force?
    end

    def run
      run_checks! if checkable_file_changes?
      push
    end

    def amend_and_push
      run_checks! if checkable_file_changes?
      Commit.amend
      @force = true
      push
    end

    def run_checks!
      return if skip_validations?

      GlobalVariables[:checks].each { |check| send("run_#{check}") }
      all_checks_pass
    end

    def checkable_file_changes?
      ruby_files_with_changes.length.positive? || javascript_files_with_changes.length.positive?
    end

    private

    attr_reader :branch, :force

    def success_output(check_name, message)
      puts message unless message&.empty?
      suffix = check_name == BUNDLE ? "complete" : "passed"
      success("#{inflector.humanize(check_name)} #{suffix}!")
      true
    end

    def error_output(check_name, message)
      puts message unless message&.empty?
      error("#{inflector.humanize(check_name)} failed!", exit: true)
    end

    def run_bundle_install
      warning("Bundling...")
      check = cmd("#{pci_path}/bin/bundle check")[:result]
      return success_output(BUNDLE, "") if check.match?(/The Gemfile's dependencies are satisfied/)

      output = cmd("#{pci_path}/bin/bundle install")
      error_message = output[:error]

      error_output(BUNDLE, error_message) if error?(output)

      success_output(BUNDLE, "")
    end

    def run_brakeman
      return if skip_brakeman?

      warning("Running #{BRAKEMAN}...")
      output = cmd("#{pci_path}/bin/brakeman")
      result = output[:result]

      error_output(BRAKEMAN, result) if error?(output)

      success_output(BRAKEMAN, success_message(output, BRAKEMAN))
    end

    def run_rubocop
      return if skip_rubocop?

      warning("Running #{RUBOCOP}...")
      output = cmd("#{pci_path}/bin/rubocop #{ruby_files_with_changes.join(' ')}")

      error_output(RUBOCOP, rubocop_error_message(output)) if error?(output)

      success_output(RUBOCOP, success_message(output, RUBOCOP))
    end

    def run_rspec
      return if skip_rspec?

      output = exec_rspec

      error_output(RSPEC, rspec_error_message(output)) if error?(output)

      success_output(RSPEC, success_message(output, RSPEC))
    end

    def exec_rspec
      if ruby_files_with_changes.empty?
        warning("Running #{RSPEC} on models, controllers, and services...")
        file_text = "spec/models spec/services"
      else
        files_word = files_to_run_for_rspec.length == 1 ? "file" : "files"
        warning("Running #{RSPEC} on #{files_to_run_for_rspec.length} #{files_word}...")
        file_text = files_to_run_for_rspec.join(" ")
      end
      cmd("RUBYOPT=\"-W0\" #{pci_path}/bin/rspec #{file_text}")
    end

    def push
      output = git(force? ? "push origin HEAD --force-with-lease" : "push origin HEAD")
      if output[:error].match?(/GitHub found \d+ (vulnerabilities|vulnerability)/)
        warning_message = format_github_warning(output[:error])
        warning(warning_message)
      end
      # need to find a way to check for an error when a push fails
      result = output[:result].chomp.strip
      output.puts result unless result.empty?
      success("Pushed work!")
    end

    def format_github_warning(text)
      text.
        chomp.
        strip.
        gsub(/(remote: |remote:\n)/, "").
        gsub(/^\n/, "").
        split("\n").
        map(&:strip)[0..1].
        join(" ")
    end

    def all_checks_pass
      success("All checks pass! ✅")
    end

    def run_yarn_lint
      return if skip_lint?

      warning("Running #{YARN_LINT}...")
      output = cmd("#{pci_path}/bin/yarn lint #{javascript_files_with_changes.join(' ')}")
      result = output[:result]

      error_output(YARN_LINT, result) if error?(output)

      success_output(YARN_LINT, success_message(output, YARN_LINT))
    end

    def javascript_files_with_changes
      result = git("status")[:result]
      result.
        split("\n").
        map(&:strip).
        grep(/^modified:.+\.js(x?)$/).
        map { |text| "#{pci_path}/#{text.gsub(/^modified:\s+/, '')}" }
    end

    def ruby_files_with_changes
      result = git("status")[:result]
      result.
        split("\n").
        map(&:strip).
        grep(/^modified:.+\.rb$/).
        map { |text| "#{pci_path}/#{text.gsub(/^modified:\s+/, '')}" }
    end

    def files_to_run_for_rspec
      return @files_to_run_for_rspec unless @files_to_run_for_rspec.nil?

      spec_files, app_files = ruby_files_with_changes.partition { _1.match?(%r{/spec/}) }
      @files_to_run_for_rspec = convert_to_unit_spec_files(app_files) + filter_non_runnable_spec_files(spec_files)
    end

    def convert_to_unit_spec_files(app_files)
      app_files.
        map { _1.gsub(%r{^#{pci_path}(/app)?}, "#{pci_path}/spec").gsub(/\.rb$/, "_spec.rb") }.
        select { cmd("test -f #{_1}")[:status].to_s[-1] == "0" }.
        uniq
    end

    def filter_non_runnable_spec_files(spec_files)
      spec_files.reject { _1.match?(/^spec\/(factories|support)/) }.uniq
    end

    def relative_path_to_pci
      Pathname.new(".").relative_path_from(Pathname.new(pci_path)).to_s
    end

    def force?
      @force || ARGV.include?("--force") || ARGV.include?("-f")
    end

    def skip_validations?
      ARGV.include?("--skip-validations") || ARGV.include?("-S")
    end

    def skip_rubocop?
      ARGV.include?("--skip-rubocop") ||
        ARGV.include?("-S") ||
        (!force? && ruby_files_with_changes.empty?)
    end

    def skip_brakeman?
      ARGV.include?("--skip-brakeman") ||
        ARGV.include?("-S") ||
        (!force? && ruby_files_with_changes.empty?)
    end

    def skip_rspec?
      ARGV.include?("--skip-rspec") ||
        ARGV.include?("-S") ||
        (!force? && ruby_files_with_changes.empty?)
    end

    def skip_lint?
      ARGV.include?("--skip-lint") ||
        ARGV.include?("-S") ||
        (!force? && javascript_files_with_changes.empty?)
    end

    def error?(output)
      output[:status].to_s.split.last == "1"
    end

    def success_message(output, validation_name)
      {
        RUBOCOP => rubocop_success_message(output),
        BRAKEMAN => brakeman_success_message(output),
        RSPEC => "no failing specs",
        YARN_LINT => lint_message(output),
      }[validation_name] || "Done!"
    end

    def rubocop_success_message(output)
      output[:result].split("...")[-1]&.strip&.gsub(/^(\.|\^)+/, "")&.strip&.split("\n")&.first
    end

    def rubocop_error_message(output)
      text = output[:result].split("...")[-1]&.strip&.gsub(/^(\.|\^)+/, "")&.strip
      "\n#{text}\n\n"
    end

    def brakeman_success_message(output)
      output[:result]&.split("\n")&.last
    end

    def rspec_error_message(output)
      "\n#{output[:result]&.strip}\n\n"
    end

    def lint_message(output)
      messages = output[:result].strip.split("\n")
      return "" unless messages

      "#{messages.first} - #{messages.last}"
    end
  end
end
