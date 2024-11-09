#class Rack::Attack
#  # Limit registration attempts from a single IP to 5 requests per minute
#  throttle('registrations/ip', limit: 5, period: 1.minute) do |req|
#    if req.path == '/users' && req.post?
#      req.ip
#    end
#  end
#
#  # Limit lost password requests from a single IP to 3 requests per minute
#  throttle('passwords/ip', limit: 3, period: 1.minute) do |req|
#    if req.path == '/users/password' && req.post?
#      req.ip
#    end
#  end
#end
