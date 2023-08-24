# frozen_string_literal: true

require "symbolized"
require_relative "global_variables"

module SystemOutput
  private

  def pad(**opts)
    puts if opts[:add_top_padding]
    yield
    puts if opts[:add_bottom_padding]
  end

  def error(text, **opts)
    opts = opts.to_symbolized_hash
    pad(**opts) { output.puts "#{color(:red)}--ERROR: #{text}#{color(:no_color)}" }
    exit if opts[:exit]
  end

  def success(text, **opts)
    opts = opts.to_symbolized_hash
    pad(**opts) { output.puts "#{color(:green)}--SUCCESS: #{text}#{color(:no_color)}" }
  end

  def warning(text, **opts)
    opts = opts.to_symbolized_hash
    pad(**opts) { output.puts "#{color(:yellow)}--WARNING: #{text}#{color(:no_color)}" }
    exit if opts[:exit]
  end

  def color(color_name)
    GlobalVariables.dig(:colors, color_name)
  end
end
