class SimpleCsv
  def self.foreach(path)
    lines = File.readlines(path, encoding: "bom|utf-8").map(&:chomp).reject(&:blank?)
    headers = parse_line(lines.shift.to_s)

    lines.each do |line|
      values = parse_line(line)
      yield headers.zip(values).to_h
    end
  end

  def self.parse_line(line)
    values = []
    current = +""
    quoted = false
    index = 0

    while index < line.length
      char = line[index]
      if quoted
        if char == '"' && line[index + 1] == '"'
          current << '"'
          index += 1
        elsif char == '"'
          quoted = false
        else
          current << char
        end
      elsif char == '"'
        quoted = true
      elsif char == ","
        values << current
        current = +""
      else
        current << char
      end
      index += 1
    end

    values << current
  end
end
