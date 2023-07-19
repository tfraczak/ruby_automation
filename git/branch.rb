# frozen_string_literal: true

require_relative "base"

module Git
  # Branch is a class that handles basic branch related logic for git
  class Branch < Base
    def self.create_branch
      new.create_branch
    end

    def self.prune
      new.prune(*ARGV.first.split)
    end

    def current
      git("rev-parse --abbrev-ref HEAD")[:result].chomp.strip
    end

    def valid_push?
      !main?
    end

    def create_branch
      checkout_main
      pull
      ask_for_pod_name
      ask_for_jira_number
      ask_for_descriptor
      build_branch
    end

    def delete(sub_string)
      checkout_main

      found_branches = find_branches(sub_string)
      too_many_branches_validation(found_branches)

      destroy_branch(branch_to_delete)
    end

    def prune(*pattern_strings)
      checkout_main
      pattern_strings.reject! { |str| str.match(/^main$/) }
      pattern = /#{pattern_strings.join('|')}/i

      branches.
        select { |branch_name| branch_name.match?(pattern) }.
        each { |branch_name| destroy_branch(branch_name) }

      nil
    end

    def checkout(sub_string)
      found_branches = find_branches(sub_string)
      too_many_branches_validation(found_branches)
      switching_with_changes_validation

      branch_name = found_branches[0]
      result = git("checkout #{branch_name}")[:error]
      success(result)
    end

    def main?
      current.match?(/^main$/)
    end

    def jira_pattern?
      current.match?(/^#{dev_initials}-(pod|eci)-[0-9]+(-[a-zA-Z0-9]+((-[a-zA-Z0-9]+)+)?)?$/i)
    end

    private

    attr_reader :pod_name, :jira_number, :descriptor

    def too_many_branches_validation(found_branches)
      return if found_branches.length == 1

      return error("No branches with that value", exit: true) if found_branches.empty?

      output.puts found_branches
      error("Found more than 1 branch with that value", exit: true)
    end

    def find_branches(sub_string)
      branches.select { |branch_name| branch_name.include?(sub_string) }.map(&:chomp)
    end

    def branches
      git("branch")[:result].
        split("\n").
        map { _1.strip.gsub(/^\*\s+/, "") }.
        reject { _1.match?(/^main$/) }
    end

    def checkout_main
      return if main?

      switching_with_changes_validation

      response = git "checkout main"
      return unless response[:error]
      return if response[:error].match?(/Switched to branch 'main'|Already on 'main'/)

      error("Checking out 'main' branch failed!", exit: true)
    end

    def pull
      git "pull"
    end

    def changes?
      status[:result].match?(/no changes added to commit/)
    end

    def ask_for_pod_name
      @pod_name = ""

      until valid_pod_name?
        output.print "Enter pod name (eci or pod): "
        @pod_name = input.gets.chomp.strip
        error("Must be 'eci' or 'pod'") unless valid_pod_name?
      end
    end

    def ask_for_jira_number
      @jira_number = ""

      until valid_jira_number?
        output.print "Enter jira number: "
        @jira_number = input.gets.chomp.strip
        error("Must be an integer") unless valid_jira_number?
      end
    end

    def ask_for_descriptor
      @descriptor = ""
      output.print "Enter branch descriptor: "
      @descriptor = input.gets.chomp.strip
      @descriptor = @descriptor.gsub(" ", "-")
    end

    def valid_pod_name?
      pod_name.match?(/^(pod|eci)$/i)
    end

    def valid_jira_number?
      jira_number.match?(/^\d+$/i)
    end

    def build_branch
      result = git("checkout -b #{dev_initials}-#{pod_name.downcase}-#{jira_number}-#{descriptor}")[:error].chomp
      success(result)
    end

    def destroy_branch(name)
      result = git("branch -D #{name}")[:result].chomp
      success(result)
    end

    def switching_with_changes_validation
      error("Cannot switch branches, please commit or stash changes", exit: true) if changes?
    end
  end
end

Git::Branch.create_branch if ENV.fetch("NEW_BRANCH", nil)
Git::Branch.prune if ENV.fetch("PRUNE", nil)
