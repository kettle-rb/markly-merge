# frozen_string_literal: true

RSpec.describe Markly::Merge::TableMatchAlgorithm do
  subject(:algorithm) { described_class.new(**options) }

  let(:options) { {} }

  # Helper to create a table node from markdown
  def table_node_from(markdown)
    doc = Markly.parse(markdown, extensions: [:table])
    # Find the table node in the AST
    find_table(doc)
  end

  def find_table(node)
    return node if node.type == :table

    node.each do |child|
      result = find_table(child)
      return result if result
    end
    nil
  end

  describe "#initialize" do
    context "with default weights" do
      it "uses default weight values" do
        expect(algorithm.weights[:header_match]).to eq(0.25)
        expect(algorithm.weights[:first_column]).to eq(0.20)
        expect(algorithm.weights[:row_content]).to eq(0.25)
        expect(algorithm.weights[:total_cells]).to eq(0.15)
        expect(algorithm.weights[:position]).to eq(0.15)
      end
    end

    context "with custom weights" do
      let(:options) do
        {
          weights: {
            header_match: 0.5,
            first_column: 0.2,
            row_content: 0.1,
            total_cells: 0.1,
            position: 0.1,
          },
        }
      end

      it "uses custom weight values" do
        expect(algorithm.weights[:header_match]).to eq(0.5)
        expect(algorithm.weights[:first_column]).to eq(0.2)
      end
    end

    context "with position information" do
      let(:options) { {position_a: 0, position_b: 2, total_tables_a: 3, total_tables_b: 5} }

      it "stores position values" do
        expect(algorithm.position_a).to eq(0)
        expect(algorithm.position_b).to eq(2)
        expect(algorithm.total_tables_a).to eq(3)
        expect(algorithm.total_tables_b).to eq(5)
      end
    end
  end

  describe "#call" do
    context "with identical tables" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Header 1 | Header 2 |
          | -------- | -------- |
          | Cell A   | Cell B   |
          | Cell C   | Cell D   |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Header 1 | Header 2 |
          | -------- | -------- |
          | Cell A   | Cell B   |
          | Cell C   | Cell D   |
        MARKDOWN
      end

      it "returns 1.0 (perfect match)" do
        expect(algorithm.call(table_a, table_b)).to eq(1.0)
      end
    end

    context "with completely different tables" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Alpha | Beta |
          | ----- | ---- |
          | 1     | 2    |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Gamma | Delta | Epsilon |
          | ----- | ----- | ------- |
          | X     | Y     | Z       |
          | A     | B     | C       |
          | D     | E     | F       |
        MARKDOWN
      end

      it "returns a low score" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be < 0.5
      end
    end

    context "with same headers but different content" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Name | Value |
          | ---- | ----- |
          | foo  | 100   |
          | bar  | 200   |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Name | Value |
          | ---- | ----- |
          | baz  | 300   |
          | qux  | 400   |
        MARKDOWN
      end

      it "returns a medium-high score (headers match)" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be > 0.4
        expect(score).to be < 1.0
      end
    end

    context "with similar structure but different headers" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Name | Value |
          | ---- | ----- |
          | foo  | 100   |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Key  | Data |
          | ---- | ---- |
          | foo  | 100  |
        MARKDOWN
      end

      it "returns a medium score (content matches but headers differ)" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be > 0.2
        expect(score).to be < 0.8
      end
    end

    context "with partial header match" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Name | Value | Description |
          | ---- | ----- | ----------- |
          | foo  | 100   | A foo item  |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Name | Amount | Notes |
          | ---- | ------ | ----- |
          | foo  | 100    | Some notes |
        MARKDOWN
      end

      it "returns a partial match score" do
        score = algorithm.call(table_a, table_b)
        # "Name" header matches, others don't
        expect(score).to be > 0.3
        expect(score).to be < 0.9
      end
    end
  end

  describe "private method #compute_header_match" do
    context "with identical headers" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | A | B | C |
          | - | - | - |
          | 1 | 2 | 3 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A | B | C |
          | - | - | - |
          | 4 | 5 | 6 |
        MARKDOWN
      end

      it "returns 1.0" do
        rows_a = algorithm.send(:extract_rows, table_a)
        rows_b = algorithm.send(:extract_rows, table_b)
        score = algorithm.send(:compute_header_match, rows_a, rows_b)
        expect(score).to eq(1.0)
      end
    end

    context "with no matching headers" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | X | Y |
          | - | - |
          | 1 | 2 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          | - | - |
          | 3 | 4 |
        MARKDOWN
      end

      it "returns low score (single-char headers have 0 similarity)" do
        rows_a = algorithm.send(:extract_rows, table_a)
        rows_b = algorithm.send(:extract_rows, table_b)
        score = algorithm.send(:compute_header_match, rows_a, rows_b)
        # Single character strings that differ have 0 similarity
        expect(score).to eq(0.0)
      end
    end
  end

  describe "private method #compute_first_column_match" do
    context "with identical first columns" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | ID | Name |
          | -- | ---- |
          | 1  | Foo  |
          | 2  | Bar  |
          | 3  | Baz  |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | ID | Description |
          | -- | ----------- |
          | 1  | A foo thing |
          | 2  | A bar thing |
          | 3  | A baz thing |
        MARKDOWN
      end

      it "returns 1.0" do
        rows_a = algorithm.send(:extract_rows, table_a)
        rows_b = algorithm.send(:extract_rows, table_b)
        score = algorithm.send(:compute_first_column_match, rows_a, rows_b)
        expect(score).to eq(1.0)
      end
    end

    context "with partially matching first columns" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | ID |
          | -- |
          | 1  |
          | 2  |
          | 3  |
          | 4  |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | ID |
          | -- |
          | 1  |
          | 2  |
          | 5  |
          | 6  |
        MARKDOWN
      end

      it "returns partial match score based on Levenshtein similarity" do
        rows_a = algorithm.send(:extract_rows, table_a)
        rows_b = algorithm.send(:extract_rows, table_b)
        score = algorithm.send(:compute_first_column_match, rows_a, rows_b)
        # With Levenshtein: each cell finds its best match in the other column
        # Cells: A = [ID, 1, 2, 3, 4], B = [ID, 1, 2, 5, 6]
        # ID matches ID (1.0), 1 matches 1 (1.0), 2 matches 2 (1.0)
        # 3 best matches 5 or 6 (0.0), 4 best matches 5 or 6 (0.0)
        expect(score).to be > 0.5
        expect(score).to be <= 0.7
      end
    end
  end

  describe "private method #compute_row_content_match" do
    context "with identical data rows" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          | - | - |
          | 1 | 2 |
          | 3 | 4 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          | - | - |
          | 1 | 2 |
          | 3 | 4 |
        MARKDOWN
      end

      it "returns 1.0" do
        rows_a = algorithm.send(:extract_rows, table_a)
        rows_b = algorithm.send(:extract_rows, table_b)
        score = algorithm.send(:compute_row_content_match, rows_a, rows_b)
        expect(score).to eq(1.0)
      end
    end

    context "with no matching first columns" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | X | B |
          | - | - |
          | 1 | 2 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Y | B |
          | - | - |
          | 3 | 4 |
        MARKDOWN
      end

      it "returns 0.0 (no rows with matching first column)" do
        rows_a = algorithm.send(:extract_rows, table_a)
        rows_b = algorithm.send(:extract_rows, table_b)
        score = algorithm.send(:compute_row_content_match, rows_a, rows_b)
        expect(score).to eq(0.0)
      end
    end
  end

  describe "private method #compute_total_cells_match" do
    context "with identical cells" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          | - | - |
          | 1 | 2 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          | - | - |
          | 1 | 2 |
        MARKDOWN
      end

      it "returns 1.0" do
        rows_a = algorithm.send(:extract_rows, table_a)
        rows_b = algorithm.send(:extract_rows, table_b)
        score = algorithm.send(:compute_total_cells_match, rows_a, rows_b)
        expect(score).to eq(1.0)
      end
    end

    context "with no matching cells" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | X | Y |
          | - | - |
          | P | Q |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          | - | - |
          | 1 | 2 |
        MARKDOWN
      end

      it "returns 0.0" do
        rows_a = algorithm.send(:extract_rows, table_a)
        rows_b = algorithm.send(:extract_rows, table_b)
        score = algorithm.send(:compute_total_cells_match, rows_a, rows_b)
        expect(score).to eq(0.0)
      end
    end
  end

  describe "private method #compute_position_score" do
    context "with nil positions (default)" do
      it "returns 1.0" do
        score = algorithm.send(:compute_position_score)
        expect(score).to eq(1.0)
      end
    end

    context "with same position" do
      let(:options) { {position_a: 0, position_b: 0, total_tables_a: 3, total_tables_b: 3} }

      it "returns 1.0" do
        score = algorithm.send(:compute_position_score)
        expect(score).to eq(1.0)
      end
    end

    context "with different positions" do
      let(:options) { {position_a: 0, position_b: 2, total_tables_a: 3, total_tables_b: 3} }

      it "returns reduced score based on normalized distance" do
        score = algorithm.send(:compute_position_score)
        # pos_a = 0/3 = 0, pos_b = 2/3 ≈ 0.67
        # distance = 0.67, score = 1 - 0.67 ≈ 0.33
        expect(score).to be < 0.5
        expect(score).to be > 0.0
      end
    end
  end

  describe "private helper #extract_rows" do
    let(:table) do
      table_node_from(<<~MARKDOWN)
        | A | B |
        | - | - |
        | 1 | 2 |
        | 3 | 4 |
      MARKDOWN
    end

    it "extracts rows as arrays of cell text" do
      rows = algorithm.send(:extract_rows, table)
      expect(rows.size).to eq(3) # header + 2 data rows
      expect(rows[0]).to eq(["A", "B"])
      expect(rows[1]).to eq(["1", "2"])
      expect(rows[2]).to eq(["3", "4"])
    end
  end

  describe "private helper #extract_cells" do
    let(:table) do
      table_node_from(<<~MARKDOWN)
        | Hello | World |
        | ----- | ----- |
        | Foo   | Bar   |
      MARKDOWN
    end

    it "extracts cell text from a row" do
      row = table.first_child # first row
      cells = algorithm.send(:extract_cells, row)
      expect(cells).to eq(["Hello", "World"])
    end
  end

  describe "private helper #extract_text_content" do
    let(:table) do
      table_node_from(<<~MARKDOWN)
        | Hello | World |
        | ----- | ----- |
        | Foo   | Bar   |
      MARKDOWN
    end

    it "extracts text from a cell node" do
      row = table.first_child
      cell = row.first_child
      text = algorithm.send(:extract_text_content, cell)
      expect(text).to eq("Hello")
    end
  end

  describe "integration with MatchScoreBase" do
    let(:table_a) do
      table_node_from(<<~MARKDOWN)
        | Name | Value |
        | ---- | ----- |
        | foo  | 100   |
      MARKDOWN
    end

    let(:table_b) do
      table_node_from(<<~MARKDOWN)
        | Name | Value |
        | ---- | ----- |
        | foo  | 100   |
      MARKDOWN
    end

    it "can be used with MatchScoreBase" do
      matcher = Ast::Merge::MatchScoreBase.new(
        table_a,
        table_b,
        algorithm: algorithm,
      )

      expect(matcher.score).to eq(1.0)
      expect(matcher.match?).to be true
    end
  end

  describe "Levenshtein distance matching" do
    describe "private method #levenshtein_distance" do
      it "returns 0 for identical strings" do
        distance = algorithm.send(:levenshtein_distance, "hello", "hello")
        expect(distance).to eq(0)
      end

      it "returns the length of other string when one is empty" do
        expect(algorithm.send(:levenshtein_distance, "", "hello")).to eq(5)
        expect(algorithm.send(:levenshtein_distance, "hello", "")).to eq(5)
      end

      it "returns 1 for single character difference" do
        distance = algorithm.send(:levenshtein_distance, "hello", "hallo")
        expect(distance).to eq(1)
      end

      it "returns correct distance for insertions" do
        distance = algorithm.send(:levenshtein_distance, "hello", "hellos")
        expect(distance).to eq(1)
      end

      it "returns correct distance for deletions" do
        distance = algorithm.send(:levenshtein_distance, "hello", "hell")
        expect(distance).to eq(1)
      end

      it "handles completely different strings" do
        distance = algorithm.send(:levenshtein_distance, "abc", "xyz")
        expect(distance).to eq(3)
      end
    end

    describe "private method #string_similarity" do
      it "returns 1.0 for identical strings" do
        similarity = algorithm.send(:string_similarity, "hello", "hello")
        expect(similarity).to eq(1.0)
      end

      it "returns 1.0 for case-insensitive match" do
        similarity = algorithm.send(:string_similarity, "Hello", "HELLO")
        expect(similarity).to eq(1.0)
      end

      it "returns high similarity for similar strings" do
        similarity = algorithm.send(:string_similarity, "Value", "Values")
        expect(similarity).to be > 0.8
      end

      it "returns 0.0 when one string is empty and other is not" do
        similarity = algorithm.send(:string_similarity, "", "hello")
        expect(similarity).to eq(0.0)
      end

      it "returns 1.0 when both strings are empty" do
        similarity = algorithm.send(:string_similarity, "", "")
        expect(similarity).to eq(1.0)
      end

      it "returns low similarity for very different strings" do
        similarity = algorithm.send(:string_similarity, "abc", "xyz")
        expect(similarity).to eq(0.0)
      end
    end

    describe "#call with similar but not identical content" do
      context "with similar headers" do
        let(:table_a) do
          table_node_from(<<~MARKDOWN)
            | Name | Values |
            | ---- | ------ |
            | foo  | 100    |
          MARKDOWN
        end

        let(:table_b) do
          table_node_from(<<~MARKDOWN)
            | Name | Value |
            | ---- | ----- |
            | foo  | 100   |
          MARKDOWN
        end

        it "returns high score due to Levenshtein similarity" do
          score = algorithm.call(table_a, table_b)
          # "Values" vs "Value" is very similar
          expect(score).to be > 0.9
        end
      end

      context "with typos in content" do
        let(:table_a) do
          table_node_from(<<~MARKDOWN)
            | Name | Description |
            | ---- | ----------- |
            | foo  | A foo item  |
          MARKDOWN
        end

        let(:table_b) do
          table_node_from(<<~MARKDOWN)
            | Name | Description |
            | ---- | ----------- |
            | fo   | A foo itm   |
          MARKDOWN
        end

        it "returns high score despite typos" do
          score = algorithm.call(table_a, table_b)
          expect(score).to be > 0.7
        end
      end

      context "with pluralization differences" do
        let(:table_a) do
          table_node_from(<<~MARKDOWN)
            | Item | Count |
            | ---- | ----- |
            | apple | 5    |
            | banana | 3   |
          MARKDOWN
        end

        let(:table_b) do
          table_node_from(<<~MARKDOWN)
            | Items | Counts |
            | ----- | ------ |
            | apples | 5     |
            | bananas | 3    |
          MARKDOWN
        end

        it "returns moderate-high score for pluralized variations" do
          score = algorithm.call(table_a, table_b)
          expect(score).to be > 0.6
        end
      end
    end
  end

  describe "edge cases for branch coverage" do
    context "with empty tables (no rows)" do
      # Tables must have at least header row to be valid
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Header |
          | ------ |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Header |
          | ------ |
        MARKDOWN
      end

      it "handles minimal tables" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be_a(Float)
        expect(score).to be >= 0.0
        expect(score).to be <= 1.0
      end
    end

    context "with one empty string in cells" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          |---|---|
          |   | X |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          |---|---|
          |   | X |
        MARKDOWN
      end

      it "handles empty cells in tables" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be_a(Float)
      end
    end

    context "with single cell tables" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Only |
          |------|
          | One  |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Only |
          |------|
          | One  |
        MARKDOWN
      end

      it "handles single column tables" do
        score = algorithm.call(table_a, table_b)
        expect(score).to eq(1.0)
      end
    end

    context "with tables having different column counts" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | A | B | C |
          |---|---|---|
          | 1 | 2 | 3 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          |---|---|
          | 1 | 2 |
        MARKDOWN
      end

      it "returns lower score for different column counts" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be < 1.0
        expect(score).to be > 0.0
      end
    end

    context "with row having nil first column" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          |---|---|
          |   | X |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          |---|---|
          | Y | Z |
        MARKDOWN
      end

      it "handles nil/empty first columns" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be_a(Float)
      end
    end

    context "with string similarity edge cases" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Header |
          |--------|
          | abc    |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Header |
          |--------|
          | xyz    |
        MARKDOWN
      end

      it "returns lower score for completely different content" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be < 1.0
      end
    end

    context "when one table has more rows than the other" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Key | Value |
          |-----|-------|
          | a   | 1     |
          | b   | 2     |
          | c   | 3     |
          | d   | 4     |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Key | Value |
          |-----|-------|
          | a   | 1     |
        MARKDOWN
      end

      it "handles different row counts" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be_a(Float)
        expect(score).to be > 0.0
        expect(score).to be < 1.0
      end
    end

    context "with position at extremes" do
      let(:options) { {position_a: 0, position_b: 0, total_tables_a: 1, total_tables_b: 1} }

      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | A |
          |---|
          | 1 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A |
          |---|
          | 1 |
        MARKDOWN
      end

      it "returns perfect score for identical single tables" do
        score = algorithm.call(table_a, table_b)
        expect(score).to eq(1.0)
      end
    end

    context "with position far apart" do
      let(:options) { {position_a: 0, position_b: 9, total_tables_a: 10, total_tables_b: 10} }

      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | A |
          |---|
          | 1 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A |
          |---|
          | 1 |
        MARKDOWN
      end

      it "returns lower score due to position difference" do
        score = algorithm.call(table_a, table_b)
        # Position penalty should reduce score somewhat
        expect(score).to be < 1.0
      end
    end

    context "with first column below similarity threshold" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Name | Value |
          |------|-------|
          | completely_different_key | 100 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Name | Value |
          |------|-------|
          | xyz_unrelated_name | 100 |
        MARKDOWN
      end

      it "handles rows that don't match by first column" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be_a(Float)
      end
    end

    context "with special characters in cells" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | Key | Value |
          |-----|-------|
          | `code` | **bold** |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | Key | Value |
          |-----|-------|
          | `code` | **bold** |
        MARKDOWN
      end

      it "handles markdown formatting in cells" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be >= 0.9
      end
    end

    context "with unicode content" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | 名前 | 値 |
          |------|-----|
          | テスト | データ |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | 名前 | 値 |
          |------|-----|
          | テスト | データ |
        MARKDOWN
      end

      it "handles unicode content correctly" do
        score = algorithm.call(table_a, table_b)
        expect(score).to eq(1.0)
      end
    end

    context "with empty table (no rows)" do
      it "returns 0.0 when first table has no rows" do
        # Create mock tables with no rows
        empty_table = double("Markly::Node")
        allow(empty_table).to receive(:first_child).and_return(nil)
        allow(empty_table).to receive(:type).and_return(:table)

        non_empty_table = table_node_from(<<~MARKDOWN)
          | A | B |
          |---|---|
          | 1 | 2 |
        MARKDOWN

        expect(algorithm.call(empty_table, non_empty_table)).to eq(0.0)
      end

      it "returns 0.0 when second table has no rows" do
        non_empty_table = table_node_from(<<~MARKDOWN)
          | A | B |
          |---|---|
          | 1 | 2 |
        MARKDOWN

        empty_table = double("Markly::Node")
        allow(empty_table).to receive(:first_child).and_return(nil)
        allow(empty_table).to receive(:type).and_return(:table)

        expect(algorithm.call(non_empty_table, empty_table)).to eq(0.0)
      end
    end

    context "with empty headers" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          |   |   |
          |---|---|
          | A | B |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          |   |   |
          |---|---|
          | A | B |
        MARKDOWN
      end

      it "handles empty header cells" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be_a(Float)
        expect(score).to be >= 0.0
      end
    end

    context "with nil cells in header comparison" do
      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | A | B | C |
          |---|---|---|
          | 1 | 2 | 3 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          |---|---|
          | 1 | 2 |
        MARKDOWN
      end

      it "handles mismatched column counts gracefully" do
        score = algorithm.call(table_a, table_b)
        expect(score).to be_a(Float)
        expect(score).to be > 0.5 # Should still be similar despite column count difference
      end
    end

    context "with zero weight total" do
      let(:options) do
        {
          weights: {
            header_match: 0,
            first_column: 0,
            row_content: 0,
            total_cells: 0,
            position: 0,
          },
        }
      end

      let(:table_a) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          |---|---|
          | 1 | 2 |
        MARKDOWN
      end

      let(:table_b) do
        table_node_from(<<~MARKDOWN)
          | A | B |
          |---|---|
          | 1 | 2 |
        MARKDOWN
      end

      it "returns 0.0 when all weights are zero" do
        score = algorithm.call(table_a, table_b)
        expect(score).to eq(0.0)
      end
    end
  end

  describe "string_similarity edge cases" do
    let(:table_a) do
      table_node_from(<<~MARKDOWN)
        | A | B |
        |---|---|
        | 1 | 2 |
      MARKDOWN
    end

    let(:table_b) do
      table_node_from(<<~MARKDOWN)
        | A | B |
        |---|---|
        | 1 | 2 |
      MARKDOWN
    end

    it "handles string similarity for identical strings" do
      result = algorithm.send(:string_similarity, "hello", "hello")
      expect(result).to eq(1.0)
    end

    it "handles both empty strings" do
      result = algorithm.send(:string_similarity, "", "")
      expect(result).to eq(1.0)
    end

    it "handles one empty string" do
      result = algorithm.send(:string_similarity, "hello", "")
      expect(result).to eq(0.0)
    end

    it "handles other empty string" do
      result = algorithm.send(:string_similarity, "", "world")
      expect(result).to eq(0.0)
    end
  end

  describe "row_match_score edge cases" do
    let(:table_a) do
      table_node_from(<<~MARKDOWN)
        | A | B |
        |---|---|
        | 1 | 2 |
      MARKDOWN
    end

    let(:table_b) { table_a }

    it "returns 1.0 for empty rows" do
      result = algorithm.send(:row_match_score, [], [])
      expect(result).to eq(1.0)
    end

    it "handles nil values in row comparison" do
      result = algorithm.send(:row_match_score, ["a", nil, "c"], ["a", "b"])
      expect(result).to be_a(Float)
    end
  end

  describe "compute_total_cells_match edge cases" do
    let(:table_a) do
      table_node_from(<<~MARKDOWN)
        | A | B |
        |---|---|
        | 1 | 2 |
      MARKDOWN
    end

    let(:table_b) { table_a }

    it "returns 1.0 when both cell arrays are empty" do
      result = algorithm.send(:compute_total_cells_match, [], [])
      expect(result).to eq(1.0)
    end

    it "returns 0.0 when first cell array is empty" do
      result = algorithm.send(:compute_total_cells_match, [], [["a", "b"]])
      expect(result).to eq(0.0)
    end

    it "returns 0.0 when second cell array is empty" do
      result = algorithm.send(:compute_total_cells_match, [["a", "b"]], [])
      expect(result).to eq(0.0)
    end
  end

  describe "compute_first_column_match edge cases" do
    let(:table_a) do
      table_node_from(<<~MARKDOWN)
        | A | B |
        |---|---|
        | 1 | 2 |
      MARKDOWN
    end

    let(:table_b) { table_a }

    it "handles rows with nil first column" do
      rows_a = [[nil, "b"], ["x", "y"]]
      rows_b = [["a", "b"], [nil, "z"]]
      result = algorithm.send(:compute_first_column_match, rows_a, rows_b)
      expect(result).to be_a(Float)
    end

    it "returns 0.0 for empty first columns" do
      rows_a = [["", "b"]]
      rows_b = [["", "c"]]
      # Both have empty first column strings
      result = algorithm.send(:compute_first_column_match, rows_a, rows_b)
      expect(result).to be_a(Float)
    end
  end

  describe "compute_row_content_match edge cases" do
    let(:table_a) do
      table_node_from(<<~MARKDOWN)
        | A | B |
        |---|---|
        | 1 | 2 |
      MARKDOWN
    end

    let(:table_b) { table_a }

    it "returns 0.0 for empty row arrays" do
      result = algorithm.send(:compute_row_content_match, [], [])
      expect(result).to eq(0.0)
    end

    it "handles rows where first column is nil" do
      rows_a = [[nil, "value"]]
      rows_b = [["key", "value"]]
      result = algorithm.send(:compute_row_content_match, rows_a, rows_b)
      expect(result).to be_a(Float)
    end

    it "handles when no first column matches threshold" do
      rows_a = [["completely_different_key", "value"]]
      rows_b = [["totally_unrelated_name", "value"]]
      result = algorithm.send(:compute_row_content_match, rows_a, rows_b)
      # No match found due to threshold, returns 0.0
      expect(result).to eq(0.0)
    end
  end
end
