# frozen_string_literal: true

require "dry/inflector"
require "pathname"
require "byebug"
require_relative "branch"
require_relative "commit"

module Git
  class Push < Base
    BUNDLE = "bundle"
    BRAKEMAN = "brakeman"
    RUBOCOP = "rubocop"
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
      GlobalVariables[:checks].each { |check| send("run_#{check}") }
      all_checks_pass
    end

    def checkable_file_changes?
      ruby_files_with_changes.length.positive? || javascript_files_with_changes.length.positive?
    end

    private

    attr_reader :branch, :force

    def success_output(check_name, message)
      puts message unless message.empty?
      suffix = check_name == BUNDLE ? "complete" : "passed"
      success("#{inflector.humanize(check_name)} #{suffix}!")
      true
    end

    def error_output(check_name, message)
      puts message unless message.empty?
      error("#{inflector.humanize(check_name)} failed!", exit: true)
    end

    def run_bundle_install
      warning("Bundling...")
      check = cmd("#{pci_path}/bin/bundle check")[:result]
      return success_output(BUNDLE, "") if check.match?(/The Gemfile's dependencies are satisfied/)

      response = cmd("#{pci_path}/bin/bundle install")
      install = response[:result]
      error_message = response[:error]

      if install.match?(/Bundle complete!/)
        success_output(BUNDLE, "")
      else
        error_output(BUNDLE, error_message)
      end
    end

    def run_brakeman
      return unless ruby_files_with_changes.length.positive? || force

      warning("Running #{BRAKEMAN}...")
      result = cmd("#{pci_path}/bin/brakeman #{pci_path}")[:result]
      if result.match?(/No warnings found/)
        success_output(BRAKEMAN, result.split("\n")[-1])
      else
        error_output(BRAKEMAN, result)
      end
    end

    # rubocop:disable Metrics/AbcSize
    def run_rubocop
      return unless ruby_files_with_changes.length.positive? || force

      warning("Running #{RUBOCOP}...")
      result = cmd("#{pci_path}/bin/rubocop")[:result]
      message = result.split("...")[-1]&.strip&.gsub(/^(\.|\^)+/, "")&.strip
      if result.match?(/no offenses detected/)
        success_output(RUBOCOP, message.split("\n")[0])
      else
        error_output(RUBOCOP, "\n#{message}")
      end
    end
    # rubocop:enable Metrics/AbcSize

    def push
      response = git(force? ? "push origin HEAD --force-with-lease" : "push origin HEAD")
      if response[:error].match?(/GitHub found \d+ (vulnerabilities|vulnerability)/)
        warning_message = format_github_warning(response[:error])
        warning(warning_message)
      end
      # need to find a way to check for an error when a push fails
      result = response[:result].chomp.strip
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
      return unless javascript_files_with_changes.length.positive?

      warning("Running #{YARN_LINT}...")
      response = cmd("#{pci_path}/bin/yarn lint #{javascript_files_with_changes.join(' ')}")
      result = response[:result]
      error = response[:error]
      error_output(YARN_LINT, result) if error.match?(/error Command failed with exit code 1/)

      messages = result.split("\n")
      success_output(YARN_LINT, "#{messages[0]} - #{messages[-1]}")
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

    def relative_path_to_pci
      Pathname.new(".").relative_path_from(Pathname.new(pci_path)).to_s
    end

    def force?
      @force || ARGV.include?("--force") || ARGV.include?("-f")
    end
  end
end
