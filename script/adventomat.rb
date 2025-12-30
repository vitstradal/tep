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
  '5.12.2025' => 47,
  '6.12.2025' => 16,
  '7.12.2025' => 168,
  '8.12.2025' => 360,
  '9.12.2025' => 10,
  '10.12.2025' => 1187,
  '11.12.2025' => 1209,
  '12.12.2025' => 20,
  '13.12.2025' => 80,
  '14.12.2025' => 111000,
  '15.12.2025' => 126,
  '16.12.2025' => 64,
  '17.12.2025' => 59,
  '18.12.2025' => 23,
  '19.12.2025' => 2143,
  '20.12.2025' => 6,
  '21.12.2025' => 90,
  '22.12.2025' => 1024,
  '23.12.2025' => 11025,
  '24.12.2025' => 42,
  'bonus2025'  => 225,
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

