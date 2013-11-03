
require 'pp'
schools = Sosna::School.create(YAML.load_file('db/skoly29.yml'))

YAML.load_file('db/lidi29.yml').each do |s|
#YAML.load_file('db/lidi29-test.yml').each do |s|

  short = s.delete "school_short"
  school = Sosna::School.find_by_short(short)
  solver = Sosna::Solver.create(s)
  solver.save
  if school
    solver.school = school
  else
    print "user: #{solver.name} #{solver.last_name} #{solver.id} has not school #{short}\n"
  end

  if ! solver.save
    pp solver.errors.messages
    pp "solver.yml:", s
    abort "fail" 
  end
  if solver.email
    user = User.find_by_email solver.email
    if !user 
      # create user by email
      print "creating user"
      user =  User.new(email: solver.email, confirmation_sent_at: Time.now,  roles: [:user])
      user.confirm!
      #user.send_first_login_instructions
      user.save
    end
    solver.user = user
    if ! solver.save
      pp solver.errors.messages
      abort "fail" 
    end
  end
end

