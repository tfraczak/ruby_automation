# frozen_string_literal: true

require "open3"
require "symbolized"

Dir[File.join(__dir__, "../lib", "*.rb")].sort.each { |file| require_relative file }

module Git
  # Base class for other Git classes to inherit from
  class Base
    class MissingDevInitialsError < StandardError; end
    class MissingPatientCheckInPathError < StandardError; end

    include SystemOutput

    def initialize
      run_validations!
      @input = $stdin
      @output = $stdout
      @pci_path = GlobalVariables["pci_path"]
    end

    def inspect
      "#{super.split('@').first.strip}>"
    end

    private

    attr_reader :input, :pci_path, :output

    def git(command)
      cmd("git -C #{pci_path} #{command}")
    end

    def dev_initials
      @dev_initials ||= GlobalVariables[:dev_initials]
    end

    def cmd(cmd_string)
      %w(result error status).zip(Open3.capture3(cmd_string)).to_h.to_symbolized_hash
    end

    def status
      git "status"
    end

    def run_validations!
      validate_project_path
      validate_dev_initials
    end

    def validate_project_path
      return unless GlobalVariables[:pci_path].nil?

      raise MissingPatientCheckInPathError, yml_file_error_text("Patient Check-In project path", :pci_path)
    end

    def validate_dev_initials
      return unless GlobalVariables[:dev_initials].nil?

      raise MissingDevInitialsError, yml_file_error_text("initials", :dev_initials)
    end

    def yml_file_error_text(text, key)
      "Must define your #{text} at \"#{key}\" in the yaml file: ./lib/globals.yml"
    end
  end
end
