# frozen_string_literal: true

require "open3"
require "dry-inflector"
require "symbolized"
require "debug"

Dir[File.join(__dir__, "../lib", "*.rb")].each { |file| require_relative file }

module Git
  class Base
    class MissingDevInitialsError < StandardError; end
    class MissingProjectPathError < StandardError; end

    include SystemOutput

    def initialize
      validate_project_path
      validate_dev_initials
      @input = $stdin
      @output = $stdout
      @project_path = GlobalVariables[:project_path]
    end

    def inspect
      super.split("@").first.strip
    end

    private

    attr_reader :input, :project_path, :output

    def inflector
      @inflector ||= Dry::Inflector.new
    end

    def git(command)
      cmd("git -C #{project_path} #{command}")
    end

    def dev_initials
      @dev_initials ||= GlobalVariables[:dev_initials]
    end

    def project_names
      @project_names ||= GlobalVariables[:project_names]
    end

    def main_branch_name
      @main_branch_name ||= GlobalVariables[:main_branch]
    end

    def cmd(cmd_string)
      %w[result error status].zip(Open3.capture3(cmd_string)).to_h.to_symbolized_hash
    end

    def success?(response)
      response[:status].success?
    end

    def multiline_gets
      all_text = []
      text = input.gets.chomp.strip
      while text != "$end"
        all_text << text
        text = input.gets.chomp.strip
      end
      all_text.join("\n")
    end

    def validate_project_path
      raise MissingProjectPathError, "Project path is missing in globals.yml" if GlobalVariables["project_path"].nil?
    end

    def validate_dev_initials
      raise MissingDevInitialsError, "Dev initials are missing in globals.yml" if GlobalVariables["dev_initials"].nil?
    end
  end
end
