# frozen_string_literal: true

require "byebug"
require "yaml"
require "symbolized"

# This class is meant to read the yml file for global variables to be used in other files
class GlobalVariables
  YML = YAML.load_file(File.expand_path("globals.yml", File.dirname(__FILE__))).to_symbolized_hash

  def self.[](key)
    YML[key]
  end

  def self.dig(*keys)
    YML.dig(*keys)
  end
end
