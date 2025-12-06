#!/usr/bin/env ruby

require 'pp'

form_name = 'adventomat2025'
col_name = 'Tvoje jméno'
col_solution = 'Tvoje řešení'
col_problem_name ='date'

solutions = {
  '1.12.2025' => 17,
  '2.12.2025' => 17,
  '3.12.2025' => 15,
  '4.12.2025' => 9,
  '5.12.2024' => 47,
  '6.12.2024' => 16,
  '7.12.2024' => 168,
#  '8.12.2024' => 28,
#  '9.12.2024' => 106,
#  '10.12.2024' => 600,
#  '11.12.2024' => 462,
#  '12.12.2024' => 70,
#  '13.12.2024' => 130,
#  '14.12.2024' => 840,
#  '15.12.2024' => 96,
#  '16.12.2024' => 520,
#  '17.12.2024' => 19,
#  '18.12.2024' => 221,
#  '19.12.2024' => 157,
#  '20.12.2024' => 90,
#  '21.12.2024' => 60,
#  '22.12.2024' => 700,
#  '23.12.2024' => 340,
#  '24.12.2024' => 165,
#  'bonus'  =>1,
}

spectrum = {}
results = {}
Inform.where({ form: form_name}).each do |inform|
  data =  inform.jdata
  next if data[col_name].nil?
  name = data[col_name].strip
  solution = data[col_solution].strip
  problem_name = data[col_problem_name].gsub(/ /,'')
  next if name.empty?
  puts "#{solution}/#{solutions[problem_name]}=#{solution.to_i == solutions[problem_name]}(#{problem_name}):#{data}"
  if solution.to_i == solutions[problem_name]
    results[name] ||= {}
    results[name][problem_name] = true
    spectrum[problem_name] ||= 0
    spectrum[problem_name] += 1
  end
end

result_count = []
results.each do |k,v|
  result_count.push [k, v.size]
end

#puts "Adam Urx:"
#results['Adam Urx'].keys.sort.each do  |problem|
#puts problem
##end

spectrum.keys.sort.each do |problem|
  puts "#{problem}: #{spectrum[problem]}"
end

result_count.sort {|a,b| r = b[1]<=>a[1]; r.zero? ? a[0]<=>b[0] : r }.each do |kv|
  name, count = kv
  puts "|| #{format('%2s', count)} || #{format('%-25s', name)} ||"
end

