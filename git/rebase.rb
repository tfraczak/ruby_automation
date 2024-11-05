# frozen_string_literal: true

require_relative "base"
require_relative "branch"
require_relative "commit"

module Git
  class Rebase < Base
    def self.main
      new.main
    end

    def initialize
      super
      @branch = Branch.new
      @branch_name = branch.current
    end

    def main
      Commit.wip unless nothing_to_commit?
      output.puts "Updating and fetching '#{main_branch_name}'"
      git "checkout #{main_branch_name}"
      git "pull"
      git "checkout #{branch_name}"
      output.puts "Rebasing '#{branch_name}' on '#{main_branch_name}'"
      response = git "rebase #{main_branch_name}"
      error(response[:error], exit: true) unless success?(response)
      output_result_from(response)
      success "Rebased '#{branch_name}' successfully on '#{main_branch_name}'"
    end

    private

    attr_reader :branch, :branch_name

    def nothing_to_commit?
      status_result = git("status")[:result]
      status_result.include?("nothing to commit, working tree clean")
    end

    def output_result_from(response)
      if response[:result].empty?
        output.puts response[:error]
      else
        output.puts response[:result]
      end
    end
  end
end
