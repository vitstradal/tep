
require 'pp'

email = ARGV[2].dup
print "name:#{email}\n"

begin
  user =  User.new(email: email, name: '', last_name: '', confirmation_sent_at: Time.now,  roles: [:user])
  user.confirm!
  user.save
rescue Exception => e
  print e
end

pp(user)
print "done\n" 

