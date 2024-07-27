# frozen_string_literal: true

require_relative 'base'
require_relative 'branch'

module Git
  class Commit < Base
    def initialize
      super
      @branch = Branch.new
      split_branch = branch_name.split('-')
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
      success('Work committed')
    end

    def git_add_all
      git 'add .'
    end

    def amend_with_no_edit
      git 'commit --amend --no-edit'
      success('Amended with recent changes!')
    end

    def run_validations!
      validate_main_branch_commit!
      validate_branch_name_pattern!
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

    def validate_branch_name_pattern!
      return if branch.jira_pattern?

      error("Branch name must follow pattern: #{dev_initials}-(#{pod_names.join('|')})-###-descriptor", exit: true)
    end

    def validate_git_status!
      status_result = git('status')[:result]
      return unless status_result.match?(/nothing to commit/)

      error('Nothing to commit', exit: true)
    end

    def handle_subject
      @subject = ''
      while subject.empty? || subject.length > 80
        ask_for_subject
        validate_subject!
      end
    end

    def ask_for_subject
      output.print 'Subject: '
      @subject = input.gets.chomp.strip
    end

    def validate_subject!
      error('Must include commit subject') if subject.empty?
      error(too_many_chars_error_message) if subject.length > 80
    end

    def too_many_chars_error_message
      diff = subject.length - 80
      char = diff == 1 ? 'character' : 'characters'
      "Subject is #{diff} #{char} too long, must be 80 characters or less"
    end

    def handle_message
      messages = []
      messages << ask_for_why
      messages << ask_for_what
      messages << ask_for_solution_verification
      messages << ask_for_next_steps
      @message = messages.join("\n")
    end

    def ask_for_why
      output.print 'Why?: '
      text = input.gets.chomp.strip
      text.empty? ? "Why?\nn/a" : "Why?\n#{text}"
    end

    def ask_for_what
      output.print 'What?: '
      text = input.gets.chomp.strip
      text.empty? ? "What?\nn/a" : "What?\n#{text}"
    end

    def ask_for_solution_verification
      output.print 'How did you verify this code solves the problem?: '
      text = input.gets.chomp.strip
      if text.empty?
        "How did you verify this code solves the problem?\n#{text}"
      else
        "How did you verify this code solves the problem?\nn/a"
      end
    end

    def ask_for_next_steps
      output.print 'Next Steps: '
      text = input.gets.chomp.strip
      text.empty? ? "Next Steps\nn/a" : "Next Steps\n#{text}"
    end

    def github_jira_link
      "\#\#\# [#{pod_name}-#{jira_number}]\(#{jira_link}\)"
    end

    def jira_link
      "https://babylist.atlassian.net/browse/#{pod_name}-#{jira_number}"
    end

    def continued_text
      '(cont.)' if continuation_branch?
    end

    def formatted_subject
      "#{github_jira_link}: #{subject}"
    end

    def commit_message
      [
        ["#{pod_name}-#{jira_number}:", subject, continued_text].compact.join(' '),
        [github_jira_link, continued_text].compact.join(' '),
        message,
      ].join("\n\n")
    end
  end
end
