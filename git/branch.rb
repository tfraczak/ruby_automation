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
      ask_for_team_name
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
      return prune_merged_branches if pattern_strings.empty?

      pattern_strings.reject! { |str| str.match(/^#{main_branch_name}$/) }
      pattern_strings.each do |pattern|
        branches = find_branches(pattern)
        branches.each { |branch| destroy_branch(branch) }
      end
    end

    def main?
      current == main_branch_name
    end

    def jira_pattern?
      current.match?(/^#{dev_initials}-(#{project_names.join('|')})-\d+-\w+((-\w+)+)?$/)
    end

    def checkout_main
      git "checkout #{main_branch_name}"
    end

    private

    attr_reader :project_name, :jira_number, :descriptor

    def find_branches(sub_string)
      git("branch --list '*#{sub_string}*'")[:result].split("\n").map(&:strip)
    end

    def too_many_branches_validation(found_branches)
      return unless found_branches.size > 1

      error("Too many branches found: #{found_branches.join(', ')}")
    end

    def destroy_branch(branch)
      git "branch -D #{branch}"
      success("Branch #{branch} deleted")
    end

    def prune_merged_branches
      git 'branch --merged | grep -v "\\*\\|main" | xargs -n 1 git branch -d'
    end

    def changes?
      status[:result].match?(/no changes added to commit/)
    end

    def ask_for_team_name
      @project_name = ""

      until valid_project_name?
        output.print "Enter project name (#{project_text}): "
        @project_name = input.gets.chomp.strip
        error("Must be #{project_text}") unless valid_project_name?
      end
    end

    def project_text
      return "#{project_names[0...-1].join(', ')}, or #{project_names[-1]}" if project_names.length > 2

      project_names.join(" or ")
    end

    def ask_for_jira_number
      @jira_number = ""

      output.print "Enter jira number: "
      @jira_number = input.gets.chomp.strip
      error("Must be an integer") unless valid_jira_number?
      until valid_jira_number?
        output.print "Enter jira number: "
        @jira_number = input.gets.chomp.strip
        error("Must be an integer") unless valid_jira_number?
      end
    end

    def ask_for_descriptor
      @descriptor = ""
      output.print "Enter branch descriptor: "
      @descriptor = input.gets.chomp.strip.gsub(" ", "-")
    end

    def valid_project_name?
      project_name.match?(/^(#{project_names.join('|')})$/i)
    end

    def valid_jira_number?
      project_name == "rg" || jira_number.match?(/^\d+$/)
    end

    def build_branch
      branch_name = [
        dev_initials,
        project_name.downcase,
        jira_number.empty? ? nil : jira_number,
        descriptor
      ].compact.join("-")
      result = git("checkout -b #{branch_name}")[:error].chomp
      success(result)
    end
  end
end
