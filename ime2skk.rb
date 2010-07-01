Encoding.default_external = Encoding.find("CP932")
while line = gets
  line.chomp!
  line.strip!
  next if line.empty?
  next if line =~ /^\!/

  a, b, c = line.split(/\t/)
  begin
    puts "#{a} /#{b}/".encode("UTF-8")
  rescue
  end
end
