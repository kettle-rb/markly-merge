#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to investigate merging issues - particularly process_match and destination preservation
#
# Run with: ruby examples/debug_merge.rb

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "benchmark"
  gem "tree_haver", path: File.expand_path(File.join("..", "..", "tree_haver"), __dir__)
  gem "markdown-merge", path: File.expand_path(File.join("..", "..", "markdown-merge"), __dir__)
  gem "markly-merge", path: File.expand_path("..", __dir__)
end

require "tree_haver"
require "markdown-merge"
require "markly-merge"

puts "=" * 70
puts "Debug: Merging in Markly::Merge"
puts "=" * 70
puts

# Simple test case - one heading and one paragraph in each
template_md = <<~MD
  # Heading

  Template paragraph content.
MD

dest_md = <<~MD
  # Heading

  Destination paragraph content.
MD

puts "Template Markdown:"
puts "-" * 70
puts template_md.inspect
puts template_md
puts

puts "Destination Markdown:"
puts "-" * 70
puts dest_md.inspect
puts dest_md
puts

# Parse with FileAnalysis
puts "Parsing with Markly::Merge::FileAnalysis..."
puts "-" * 70

template_analysis = Markly::Merge::FileAnalysis.new(template_md)
dest_analysis = Markly::Merge::FileAnalysis.new(dest_md)

puts "Template analysis valid: #{template_analysis.valid?}"
puts "Dest analysis valid: #{dest_analysis.valid?}"
puts

puts "Template statements (#{template_analysis.statements.size}):"
template_analysis.statements.each_with_index do |stmt, idx|
  merge_type = stmt.respond_to?(:merge_type) ? stmt.merge_type : "N/A"
  raw_type = stmt.respond_to?(:type) ? stmt.type : "N/A"
  puts "  [#{idx}] merge_type=#{merge_type.inspect}, type=#{raw_type.inspect}"
  # Try to get text content
  if stmt.respond_to?(:to_plaintext)
    puts "       to_plaintext: #{stmt.to_plaintext.inspect}"
  elsif stmt.respond_to?(:string_content)
    puts "       string_content: #{stmt.string_content.inspect}"
  end
end
puts

puts "Dest statements (#{dest_analysis.statements.size}):"
dest_analysis.statements.each_with_index do |stmt, idx|
  merge_type = stmt.respond_to?(:merge_type) ? stmt.merge_type : "N/A"
  raw_type = stmt.respond_to?(:type) ? stmt.type : "N/A"
  puts "  [#{idx}] merge_type=#{merge_type.inspect}, type=#{raw_type.inspect}"
  if stmt.respond_to?(:to_plaintext)
    puts "       to_plaintext: #{stmt.to_plaintext.inspect}"
  elsif stmt.respond_to?(:string_content)
    puts "       string_content: #{stmt.string_content.inspect}"
  end
end
puts

# Debug the source_range method
puts "Testing source_range and source_position..."
puts "-" * 70

dest_analysis.statements.each_with_index do |stmt, idx|
  pos = stmt.source_position
  puts "  Stmt[#{idx}] type=#{stmt.type}"
  puts "    source_position: #{pos.inspect}"
  puts "    source_range(#{pos[:start_line]}, #{pos[:end_line]}): #{dest_analysis.source_range(pos[:start_line], pos[:end_line]).inspect}"
end
puts

# Debug the inner node's methods
puts "Testing inner node (Markly::Node) methods..."
puts "-" * 70

d_para = dest_analysis.statements.find { |s| s.merge_type == :paragraph }
puts "Dest paragraph wrapper:"
puts "  class: #{d_para.class}"

if d_para.respond_to?(:node)
  inner = d_para.node
  puts "  inner node class: #{inner.class}"
  puts "  inner.inner_node class: #{inner.inner_node.class}"

  # Check what methods the actual Markly::Node has
  real_node = inner.inner_node
  puts "\n  Real Markly::Node methods related to content:"
  methods = real_node.methods.grep(/to_|string|content|text|render|html|markdown|plaintext/)
  puts "    #{methods.sort.join(', ')}"

  # Try each method
  puts "\n  Method output tests:"
  methods.sort.each do |meth|
    begin
      result = real_node.send(meth)
      puts "    #{meth}: #{result.inspect[0..80]}"
    rescue => e
      puts "    #{meth}: ERROR - #{e.message}"
    end
  end
end
puts

# Debug: Check if source_position is correct on the inner node
puts "Testing inner node source_position..."
puts "-" * 70

dest_analysis.statements.each_with_index do |stmt, idx|
  if stmt.respond_to?(:node)
    inner = stmt.node
    real_node = inner.inner_node
    puts "  Stmt[#{idx}] type=#{stmt.type}"
    puts "    wrapper.source_position: #{stmt.source_position.inspect}"
    puts "    inner.source_position: #{inner.source_position.inspect}"

    # Check all ways Markly might expose position
    puts "    real_node methods for position:"
    pos_methods = real_node.methods.grep(/line|column|position|source|start|end|range/)
    puts "      #{pos_methods.sort.join(', ')}"

    # Try source_position hash accessor
    if real_node.respond_to?(:source_position)
      puts "    real_node.source_position: #{real_node.source_position.inspect}"
    end

    # Try individual accessors
    puts "    real_node.start_line via method_missing: #{real_node.start_line rescue 'N/A'}"

    # Check if it's a hash-like accessor
    begin
      sp = real_node.source_position
      puts "    real_node.source_position[:start_line]: #{sp[:start_line]}" if sp
    rescue => e
      puts "    source_position accessor ERROR: #{e.message}"
    end
  end
end
puts

# Try SmartMerger
puts "Testing SmartMerger with preference: :destination..."
puts "-" * 70

begin
  merger = Markly::Merge::SmartMerger.new(
    template_md,
    dest_md,
    preference: :destination,
    add_template_only_nodes: false,
  )

  puts "Merger created successfully"
  puts "  template_analysis class: #{merger.template_analysis.class}"
  puts "  dest_analysis class: #{merger.dest_analysis.class}"

  result = merger.merge
  puts "\nMerge result:"
  puts result.inspect
  puts
  puts "Content:"
  puts result
  puts

  if result.include?("Destination paragraph")
    puts "✓ SUCCESS: Destination content preserved"
  else
    puts "✗ FAILURE: Destination content NOT preserved"
    puts "  Expected to find: 'Destination paragraph'"
    puts "  Got: #{result.inspect}"
  end
rescue => e
  puts "ERROR: #{e.class}: #{e.message}"
  puts e.backtrace.first(10).join("\n")
end
puts

puts "=" * 70
puts "Debug complete"
puts "=" * 70

