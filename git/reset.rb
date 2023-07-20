# frozen_string_literal: true

require_relative "base"
require_relative "branch"

module Git
  # Git::Reset is for resetting to the previous commit
  class Reset < Base
    class ResetMainBranchError < StandardError; end

    def self.reset_to_previous_commit
      new.reset_to_previous_commit
    end

    def reset_to_previous_commit
      raise ResetMainBranchError, "Cannot reset on '#{main_branch_name}'" if Branch.new.main?

      commit_array = git("log --oneline")[:result].split("\n")[1].split(" ")
      git "reset #{commit_array[0]}"
      success("Reset to the previous commit with subject: #{commit_array[1..].join(' ')}")
    end
  end
end

Git::Reset.reset_to_previous_commit if ENV.fetch("RESET_TO_PREV", nil)
