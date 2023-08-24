# frozen_string_literal: true

require_relative "base"
require_relative "branch"

module Git
  class Commit < Base
    def initialize
      super
      @branch = Branch.new
      split_branch = branch_name.split("-")
      @pod_name = split_branch[1].upcase
      @jira_number = split_branch[2]
    end

    def self.call
      new.run
    end

    def self.amend
      new.amend
    end

    def run
      run_validations!
      handle_subject
      handle_message
      commit
    end

    def amend
      git_add_all
      amend_with_no_edit
    end

    private

    attr_reader :branch, :jira_number, :message, :pod_name, :subject

    def commit
      git_add_all
      response = git "commit -m \"#{commit_message}\""
      result = response[:result]
      error_message = response[:error]
      error(error_message, exit: true) unless error_message.empty?
      output.puts result
      success("Work committed")
    end

    def git_add_all
      git "add ."
    end

    def amend_with_no_edit
      git "commit --amend --no-edit"
      success("Amended with recent changes!")
    end

    def run_validations!
      validate_main_branch_commit!
      validate_branch_name_pattern!
      validate_git_status!
    end

    def branch_name
      branch.current
    end

    def validate_main_branch_commit!
      return unless branch.main?

      error("Cannot commit to '#{main_branch_name}' branch", exit: true)
    end

    def validate_branch_name_pattern!
      return if branch.jira_pattern?

      error("Branch name must follow pattern: #{dev_initials}-(#{pod_names.join('|')})-###-descriptor", exit: true)
    end

    def validate_git_status!
      status_result = git("status")[:result]
      return unless status_result.match?(/nothing to commit/)

      error("Nothing to commit", exit: true)
    end

    def handle_subject
      @subject = ""
      while subject.empty? || subject.length > 80
        ask_for_subject
        validate_subject!
      end
    end

    def ask_for_subject
      output.print "Subject: "
      @subject = input.gets.chomp.strip
    end

    def validate_subject!
      error("Must include commit subject") if subject.empty?
      error(too_many_chars_error_message) if subject.length > 80
    end

    def too_many_chars_error_message
      diff = subject.length - 80
      char = diff == 1 ? "character" : "characters"
      "Subject is #{diff} #{char} too long, must be 80 characters or less"
    end

    def handle_message
      @message = ""
      while message.empty?
        ask_for_message
        validate_message!
      end
    end

    def ask_for_message
      output.print "Message: "
      @message = input.gets.chomp.strip.split('\n').join("\n")
    end

    def validate_message!
      error("Must include commit message") if message.empty?
    end

    def github_jira_link
      "\#\#\# [#{pod_name}-#{jira_number}]\(#{jira_link}\)"
    end

    def jira_link
      "https://epion-health.atlassian.net/browse/#{pod_name}-#{jira_number}"
    end

    def commit_message
      "#{subject}\n\n#{github_jira_link}\n\n#{message}\n\n#{jira_link}"
    end
  end
end
