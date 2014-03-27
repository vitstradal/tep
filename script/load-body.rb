require 'pp'
require 'csv'

annual = 29
round  = 2
body_file =  "body#{annual}_#{round}.pik"

problems = Sosna::Problem.where( annual: annual, round: round)
problems_by_num = {}
problems.each {|p| problems_by_num[p.problem_no]=p}

print "problems:"
pp(problems_by_num)


CSV.foreach(body_file, col_sep: ';') do |row| 
  next if row[0] =~ /^%/
  body = row[4].split(//);
  id = row[0].to_i
  print row if id == 0

  solver = Sosna::Solver.find(id)
  print  solver, "\n"
  (1 .. 7) .each do  |no|
     sol = Sosna::Solution.where(solver_id: solver.id, problem_id: problems_by_num[no].id).first
     b = body[no-1]
     if b != '-'
        print "   #{sol} --> #{b.to_i}\n"
        sol.score = b.to_i
        sol.has_paper_mail = sol.filename.nil?
        sol.save
     end
  end
  pen = Sosna::Penalisation.where(solver_id: solver.id, round: round, annual: annual).first
  p = body[7]
  if p != '-'
    print "   #{pen} --> #{p.to_i}\n"
    pen.score = p.to_i
    pen.save
  end

  #print "id:#{row[0]} body: #{pp(body)}\n"
end




