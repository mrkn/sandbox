TIOCGWINSZ = case RUBY_PLATFORM
             when /cygwin|mswin|mingw/
               0x5401
             when /darwin/
               0x40087468
             else
               0x5413
             end

buf = [0, 0, 0, 0].pack("S4")
winsz = $stdout.ioctl(TIOCGWINSZ, buf)
puts "TIOCGWINSZ"
p buf.unpack("S4")

$stdout.puts "\e[14t"

x = $stdin.gets(chomp: true)
p x
