require 'date'

require 'rubygems'
require 'active_support/core_ext/date'

origin = Date.new(2010, 8, 1)
offsets = [0, 1, 3, 7, 14, 28, 60, 180, 360].freeze
schedules = {}
[*7..45, *1..3].each_with_index do |section, i|
  offsets.each_with_index do |offset, j|
    date = origin + i + offset
    schedules[date] ||= []
    schedules[date] << [section, j]
  end
end
[*4..6].reverse.each do |section|
  schedules.keys.sort.each do |date|
    if schedules[date][0][0] == 1 + section
      j = schedules[date][0][1]
      date -= 1
      if date >= origin
        schedules[date] ||= []
        schedules[date].unshift [section, j]
      end
    end
  end
end
schedules.keys.sort.each do |date|
  puts "#{date}(#{schedules[date].size}): #{schedules[date].map(&:first).join(', ')}"
end

