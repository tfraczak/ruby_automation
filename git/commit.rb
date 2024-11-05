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

    def self.wip!
      new.wip!
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

    def wip!
      git_add_all
      response = git "commit -m \"WIP: #{branch_name}\""
      result = response[:result]
      error_message = response[:error]
      error(error_message, exit: true) unless error_message.empty?
      output.puts result
      success("Commited as a work in progress")
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
      validate_git_status!
    end

    def branch_name
      branch.current
    end

    def continuation_branch?
      branch_name.match?(/-cont$/)
    end

    def validate_main_branch_commit!
      return unless branch.main?

      error("Cannot commit to '#{main_branch_name}' branch", exit: true)
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
      output.puts
    end

    def ask_for_subject
      output.print "#{color(:yellow)}Subject:#{color(:no_color)} "
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
      messages = []
      messages << ask_for_why
      output.puts
      messages << ask_for_what
      output.puts
      messages << ask_for_solution_verification
      output.puts
      messages << ask_for_next_steps
      output.puts
      @message = messages.join("\n\n")
    end

    def ask_for_why
      yellow_question "Why?:"
      text = multiline_gets
      header_text = "## Why?\n\n"
      header_text += "### #{pod_name}-#{jira_number}\n\n" if branch.jira_pattern?
      text.empty? ? "#{header_text}\n\nn/a" : "#{header_text}\n\n#{text}"
    end

    def ask_for_what
      yellow_question "What?:"
      text = multiline_gets
      text.empty? ? "## What?\n\nn/a" : "## What?\n\n#{text}"
    end

    def ask_for_solution_verification
      yellow_question "How did you verify this code solves the problem?:"
      text = multiline_gets
      if text.empty?
        "## How did you verify this code solves the problem?\n\nn/a"
      else
        "## How did you verify this code solves the problem?\n\n#{text}"
      end
    end

    def ask_for_next_steps
      yellow_question "Next Steps:"
      text = multiline_gets
      text.empty? ? "## Next Steps\n\nn/a" : "## Next Steps\n\n#{text}"
    end

    def github_jira_link
      "[#{pod_name}-#{jira_number}]\(#{jira_link}\)"
    end

    def jira_link
      "https://babylist.atlassian.net/browse/#{pod_name}-#{jira_number}"
    end

    def formatted_subject
      if jira_number.empty?
        subject
      else
        "#{pod_name}-#{jira_number}: #{subject}"
      end
    end

    def commit_message
      [
        formatted_subject,
        "\n\n",
        message
      ].join("\n\n")
    end

    def yellow_question(text)
      output.puts "#{color(:yellow)}#{text}#{color(:no_color)}"
      output.puts
    end
  end
end
