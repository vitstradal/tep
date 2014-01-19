def merge(s1,s2)
  raise "not the same solver id" if s1.solver_id != s1.solver_id
  raise "not the same problem id" if s1.problem_id != s1.problem_id

  raise "duple" if !s1.filename.nil? &&  !s2.filename.nil?
  raise "duple" if !s1.filename_corr.nil? &&  !s2.filename_corr.nil?
  raise "duple" if !s1.filename_corr_display.nil? &&  !s2.filename_corr_display.nil?
  raise "duple" if !s1.filename_orig.nil? && !s2.filename_orig.nil?

  s1.filename ||= s2.filename
  s1.filename_corr ||= s2.filename_corr
  s1.filename_corr_display ||= s2.filename_corr_display
  s1.filename_orig ||= s2.filename_orig
  s1.score ||= s2.score
  s1.has_paper_mail ||= s2.has_paper_mail
end

solvers = Sosna::Solver.all

Sosna::Problem.all.each do |pr|

  solvers.each do |solver|
    sols = Sosna::Solution.where(
                                            'problem_id' => pr.id,
                                            'solver_id' => solver.id).all 
    if sols.size > 1 
      fn = 0
      fnr = 0
      sc = 0
      pa = 0

      sols.each do |s|
        fn+= 1 if !s.filename.nil?
        fnr+= 1 if !s.filename_corr.nil?
        sc+= 1 if !s.score.nil?
        pa+= 1 if s.has_paper_mail
      end
      print "bad\n"
      print "pr#{pr.id},rel#{solver.id}:fn#{fn}, fnr#{fnr} pa#{pa} sc#{sc}\n" if fn > 1 || fnr > 1 || sc > 1 || pa > 1

#      fst = sols.shift
#      sols.each do |s|
#        merge(fst,s)
#      end 
#      fst.save
#      sols.each do |s| 
#         s.destroy
#      end
    end 
  end
end


