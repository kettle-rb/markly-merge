#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to investigate table matching issues
#
# Run with: ruby examples/debug_table_matching.rb

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "benchmark"
  gem "tree_haver", path: File.expand_path(File.join("..", "..", "tree_haver"), __dir__)
  gem "markdown-merge", path: File.expand_path(File.join("..", "..", "markdown-merge"), __dir__)
  gem "markly-merge", path: File.expand_path("..", __dir__)
end

require "tree_haver"
require "markdown-merge"
require "markly-merge"

puts "=" * 70
puts "Debug: Table Matching in Markly::Merge"
puts "=" * 70
puts

# Test markdown with tables
template_md = <<~MD
  # Document

  | Name | Age | City |
  |------|-----|------|
  | Alice | 30 | NYC |
  | Bob | 25 | LA |

  Some text here.

  | Product | Price | Stock |
  |---------|-------|-------|
  | Widget | $10 | 100 |
  | Gadget | $20 | 50 |
MD

dest_md = <<~MD
  # Document

  | Name | Age | Location |
  |------|-----|----------|
  | Alice | 30 | Boston |
  | Charlie | 35 | Chicago |

  Some other text.

  | Item | Cost | Quantity |
  |------|------|----------|
  | Widget | $15 | 80 |
MD

puts "Template Markdown:"
puts "-" * 70
puts template_md
puts

puts "Destination Markdown:"
puts "-" * 70
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

# List all statements
puts "Template statements:"
puts "-" * 70
template_analysis.statements.each_with_index do |stmt, idx|
  merge_type = stmt.respond_to?(:merge_type) ? stmt.merge_type : "N/A"
  raw_type = stmt.respond_to?(:type) ? stmt.type : "N/A"
  typed_node = Ast::Merge::NodeTyping.typed_node?(stmt)
  puts "  [#{idx}] merge_type=#{merge_type.inspect}, type=#{raw_type.inspect}, typed_node?=#{typed_node}"
end
puts

puts "Dest statements:"
puts "-" * 70
dest_analysis.statements.each_with_index do |stmt, idx|
  merge_type = stmt.respond_to?(:merge_type) ? stmt.merge_type : "N/A"
  raw_type = stmt.respond_to?(:type) ? stmt.type : "N/A"
  typed_node = Ast::Merge::NodeTyping.typed_node?(stmt)
  puts "  [#{idx}] merge_type=#{merge_type.inspect}, type=#{raw_type.inspect}, typed_node?=#{typed_node}"
end
puts

# Filter tables
puts "Filtering for tables..."
puts "-" * 70

template_tables = template_analysis.statements.select do |n|
  n.respond_to?(:merge_type) && n.merge_type == :table
end

dest_tables = dest_analysis.statements.select do |n|
  n.respond_to?(:merge_type) && n.merge_type == :table
end

puts "Template tables found: #{template_tables.size}"
template_tables.each_with_index do |t, idx|
  puts "  Table #{idx}: merge_type=#{t.merge_type.inspect}, type=#{t.type.inspect}"
  if t.respond_to?(:source_position)
    puts "    source_position: #{t.source_position.inspect}"
  else
    puts "    source_position: N/A"
  end
end
puts

puts "Dest tables found: #{dest_tables.size}"
dest_tables.each_with_index do |t, idx|
  puts "  Table #{idx}: merge_type=#{t.merge_type.inspect}, type=#{t.type.inspect}"
  if t.respond_to?(:source_position)
    puts "    source_position: #{t.source_position.inspect}"
  else
    puts "    source_position: N/A"
  end
end
puts

# Test TableMatchRefiner
puts "Testing TableMatchRefiner..."
puts "-" * 70

refiner = Markdown::Merge::TableMatchRefiner.new(threshold: 0.5)

# Check table_node? method
puts "Testing table_node? on template tables:"
template_tables.each_with_index do |t, idx|
  result = refiner.send(:table_node?, t)
  puts "  Table #{idx}: table_node? = #{result}"
end
puts

puts "Testing table_node? on dest tables:"
dest_tables.each_with_index do |t, idx|
  result = refiner.send(:table_node?, t)
  puts "  Table #{idx}: table_node? = #{result}"
end
puts

# Call the refiner
puts "Calling refiner.call(template_tables, dest_tables)..."
matches = refiner.call(template_tables, dest_tables)
puts "Matches found: #{matches.size}"
matches.each_with_index do |m, idx|
  puts "  Match #{idx}: score=#{m.score}, template=#{m.template_node.type}, dest=#{m.dest_node.type}"
end
puts

# Debug extract_tables
puts "Debug: extract_tables inside refiner..."
puts "-" * 70
extracted_template = refiner.send(:extract_tables, template_tables)
extracted_dest = refiner.send(:extract_tables, dest_tables)
puts "Extracted template tables: #{extracted_template.size}"
puts "Extracted dest tables: #{extracted_dest.size}"
puts

# Debug compute_table_similarity directly
puts "Debug: compute_table_similarity for each pair..."
puts "-" * 70
template_tables.each_with_index do |t_table, t_idx|
  dest_tables.each_with_index do |d_table, d_idx|
    begin
      score = refiner.send(:compute_table_similarity, t_table, d_table, t_idx, d_idx, template_tables.size, dest_tables.size)
      puts "  Template[#{t_idx}] vs Dest[#{d_idx}]: score=#{score}"
    rescue => e
      puts "  Template[#{t_idx}] vs Dest[#{d_idx}]: ERROR - #{e.class}: #{e.message}"
      puts "    #{e.backtrace.first(5).join("\n    ")}"
    end
  end
end
puts

# Debug TableMatchAlgorithm directly
puts "Debug: TableMatchAlgorithm.call directly..."
puts "-" * 70
algorithm = Markdown::Merge::TableMatchAlgorithm.new(
  position_a: 0,
  position_b: 0,
  total_tables_a: 2,
  total_tables_b: 2,
)
begin
  score = algorithm.call(template_tables[0], dest_tables[0])
  puts "Direct algorithm call: score=#{score}"
rescue => e
  puts "Direct algorithm call: ERROR - #{e.class}: #{e.message}"
  puts "  #{e.backtrace.first(10).join("\n  ")}"
end
puts

# Debug table row extraction
puts "Debug: Table row extraction..."
puts "-" * 70
t_table = template_tables[0]
puts "Template table[0] children:"
if t_table.respond_to?(:first_child)
  child = t_table.first_child
  idx = 0
  while child
    puts "  Child #{idx}: type=#{child.type rescue 'N/A'}"
    child = child.respond_to?(:next_sibling) ? child.next_sibling : nil
    idx += 1
  end
elsif t_table.respond_to?(:children)
  t_table.children.each_with_index do |child, idx|
    puts "  Child #{idx}: type=#{child.type rescue 'N/A'}"
  end
else
  puts "  No children method available"
end
puts

# Debug walk method on table
puts "Debug: walk method on table..."
puts "-" * 70
puts "Template table[0] walk:"
if t_table.respond_to?(:walk)
  begin
    row_count = 0
    t_table.walk do |child|
      if child.type.to_s.include?("row") || child.type == :table_row
        row_count += 1
        puts "  Row #{row_count}: type=#{child.type}"
      end
    end
    puts "  Total rows found via walk: #{row_count}"
  rescue => e
    puts "  walk ERROR: #{e.class}: #{e.message}"
    puts "    #{e.backtrace.first(3).join("\n    ")}"
  end
else
  puts "  walk method not available"
end
puts

# Debug the underlying node structure
puts "Debug: Node structure details..."
puts "-" * 70
puts "Template table[0]:"
puts "  class: #{t_table.class}"
puts "  respond_to?(:node): #{t_table.respond_to?(:node)}"
if t_table.respond_to?(:node)
  inner = t_table.node
  puts "  inner node class: #{inner.class}"
  puts "  inner respond_to?(:each): #{inner.respond_to?(:each)}"
  puts "  inner respond_to?(:first_child): #{inner.respond_to?(:first_child)}"
  puts "  inner respond_to?(:walk): #{inner.respond_to?(:walk)}"
end
puts

puts "=" * 70
puts "Debug complete"
puts "=" * 70

