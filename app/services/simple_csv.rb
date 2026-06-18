class SimpleCsv
  def self.foreach(path)
    lines = File.readlines(path, encoding: "bom|utf-8").map(&:chomp).reject(&:blank?)
    headers = lines.shift.to_s.split(",", -1)

    lines.each do |line|
      values = line.split(",", -1)
      yield headers.zip(values).to_h
    end
  end
end
