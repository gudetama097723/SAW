require "test_helper"

class SeedCsvIntegrityTest < ActiveSupport::TestCase
  test "seed csv files stay utf-8 with bom and parse consistently" do
    csv_paths.each do |path|
      data = File.binread(path)

      assert_equal [0xEF, 0xBB, 0xBF], data.bytes.first(3), "#{path.basename} must keep a UTF-8 BOM"
      assert data.dup.force_encoding(Encoding::UTF_8).valid_encoding?, "#{path.basename} is not valid UTF-8"
      assert_crlf_line_endings(path, data)

      assert_consistent_columns(path)
      assert_simple_csv_parses(path)
    end
  end

  private

  def csv_paths
    Rails.root.glob("db/seeds/*.csv").sort
  end

  def assert_consistent_columns(path)
    lines = File.readlines(path, encoding: "bom|utf-8").map(&:chomp).reject(&:blank?)
    expected_columns = SimpleCsv.parse_line(lines.first.to_s).size

    lines.each.with_index(1) do |line, line_number|
      columns = SimpleCsv.parse_line(line).size
      assert_equal expected_columns, columns, "#{path.basename}:#{line_number} has #{columns} columns, expected #{expected_columns}"
    end
  end

  def assert_crlf_line_endings(path, data)
    crlf_count = data.scan("\r\n").size

    assert crlf_count.positive?, "#{path.basename} must use CRLF line endings"
    assert_equal crlf_count, data.count("\r"), "#{path.basename} has stray CR characters"
    assert_equal crlf_count, data.count("\n"), "#{path.basename} has bare LF line endings"
  end

  def assert_simple_csv_parses(path)
    SimpleCsv.foreach(path) { |_row| }
  rescue StandardError => e
    flunk "#{path.basename} must parse with SimpleCsv: #{e.class} - #{e.message}"
  end
end
