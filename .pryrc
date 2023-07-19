# frozen_string_literal: true

Dir["./lib/*.rb"].sort.each { |file| require_relative file }
Dir["./git/*.rb"].sort.each { |file| require_relative file }
