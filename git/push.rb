# frozen_string_literal: true

require_relative "branch"
require_relative "commit"

module Git
  # Git::Push is the logic used for anything related to pushing work
  class Push < Base
    BUNDLE = "bundle"
    BRAKEMAN = "brakeman"
    RUBOCOP = "rubocop"

    def self.call
      new.run
    end

    def self.amend_and_push
      new.amend_and_push
    end

    def initialize
      super
      @branch = Branch.new
      @force =  ENV.fetch("FORCE", false)
    end

    def run
      bundle_install
      run_brakeman
      run_rubocop
      all_checks_pass
      push
    end

    def amend_and_push
      bundle_install
      run_brakeman
      run_rubocop
      all_checks_pass
      Commit.amend
      @force = true
      push
    end

    private

    attr_reader :branch, :force

    def warn_and_get_result(check_name)
      warning("Running #{check_name}...")

      cmd("#{pci_path}/bin/#{check_name}")[:result]
    end

    def titleize(text)
      text[0].upcase + text[1..]
    end

    def success_output(check_name, message)
      puts message unless message.empty?
      suffix = check_name == BUNDLE ? "complete" : "passed"
      success("#{titleize(check_name)} #{suffix}!")
      true
    end

    def error_output(check_name, message)
      puts message unless message.empty?
      error("#{titleize(check_name)} failed!", exit: true)
    end

    def bundle_install
      warning("Bundling...")
      check = cmd("bundle check")[:result]
      return success_output(BUNDLE, "") if check.match?(/The Gemfile's dependencies are satisfied/)

      install = response[:result]
      error_message = response[:error]

      if install.match?(/Bundle complete!/)
        success_output(BUNDLE, "")
      else
        error_output(BUNDLE, error_message)
      end
    end

    def run_brakeman
      result = warn_and_get_result(BRAKEMAN)

      if result.match?(/No warnings found/)
        success_output(BRAKEMAN, result.split("\n")[-1])
      else
        error_output(BRAKEMAN, result)
      end
    end

    def run_rubocop
      result = warn_and_get_result(RUBOCOP)

      message = result.split("...")[-1].strip.gsub(/^(\.|\^)+/, "").strip
      if result.match?(/no offenses detected/)
        success_output(RUBOCOP, message.split("\n")[0])
      else
        error_output(RUBOCOP, "\n#{message}")
      end
    end

    def push
      response = git(force ? "push origin HEAD --force-with-lease" : "push origin HEAD")
      if response[:error].match?(/GitHub found \d+ (vulnerabilities|vulnerability)/)
        warning_message = format_github_warning(response[:error])
        warning(warning_message)
      end

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
  end
end

Git::Push.call if ENV.fetch("PUSH", nil)
Git::Push.amend_and_push if ENV.fetch("AMEND_AND_PUSH", nil)
