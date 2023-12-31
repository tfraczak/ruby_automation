# frozen_string_literal: true

require_relative "base"

module Git
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
      git "pull"
      ask_for_pod_name
      ask_for_jira_number
      ask_for_descriptor
      setup_branch
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
      return prune_merged_branches if pattern_strings.empty?

      pattern_strings.reject! { |str| str.match(/^#{main_branch_name}$/) }
      pattern = /#{pattern_strings.join('|')}/i

      branches.
        grep(pattern).
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
      current.match?(/^#{main_branch_name}$/)
    end

    def jira_pattern?
      current.match?(/^#{dev_initials}-(#{pod_names.join("|")})-[0-9]+(-[a-zA-Z0-9]+((-[a-zA-Z0-9]+)+)?)?$/i)
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
        reject { _1.match?(/^#{main_branch_name}$/) }
    end

    def checkout_main
      return if main?

      switching_with_changes_validation

      response = git "checkout #{main_branch_name}"
      return unless response[:error]
      return if response[:error].match?(/Switched to branch '#{main_branch_name}'|Already on '#{main_branch_name}'/)

      error("Checking out 'main' branch failed!", exit: true)
    end

    def changes?
      status[:result].match?(/no changes added to commit/)
    end

    def ask_for_pod_name
      @pod_name = ""

      until valid_pod_name?
        output.print "Enter pod name (#{pod_text}): "
        @pod_name = input.gets.chomp.strip
        error("Must be #{pod_text}") unless valid_pod_name?
      end
    end

    def pod_text
      pod_names.length > 2 ? "#{pod_names[0...-1].join(', ')}, or #{pod_names[-1]}" : pod_names.join(" or ")
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
      pod_name.match?(/^(#{pod_names.join("|")})$/i)
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

    def setup_branch
      cmd "bundle check || bundle install"
      cmd "rails db:migrate"
      cmd "yarn install"
    end

    def prune_merged_branches
      branches_to_delete = branches.grep(Regexp.new(merged_branches))
      return warning("No branches to delete", exit: true) if branches_to_delete.empty?

      branches_to_delete.each { destroy_branch(_1) }

      nil
    end

    def merged_branches
      git("log")[:result].
        split(/commit\s[A-Za-z0-9]+\s|\(HEAD \-\> main, origin\/main, origin\/HEAD\)/).
        map(&:strip).
        reject(&:empty?).
        map { _1.split("\n") }.
        map { _1.grep(/https\:\/\/(healthsparq|epion\-health).atlassian.net/)}.
        reject(&:empty?).
        flatten.
        map { _1.match(/\d{4}/)&.[](0) }.
        compact.
        uniq.
        sort { |a, b| a.to_i <=> b.to_i }.
        join("|")
    end
  end
end
