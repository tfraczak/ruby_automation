# frozen_string_literal: true

require 'open3'
require 'dry-inflector'
require 'symbolized'
require 'debug'

Dir[File.join(__dir__, '../lib', '*.rb')].each { |file| require_relative file }

module Git
  class Base
    class MissingDevInitialsError < StandardError; end
    class MissingPatientCheckInPathError < StandardError; end

    include SystemOutput

    def initialize
      validate_project_path
      validate_dev_initials
      @input = $stdin
      @output = $stdout
      @project_path = GlobalVariables['project_path']
    end

    def inspect
      super.split('@').first.strip
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

    def cmd(cmd_string)
      %w[result error status].zip(Open3.capture3(cmd_string)).to_h.to_symbolized_hash
    end
  end
end
