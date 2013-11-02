#!/usr/bin/env ruby

require 'yaml'

out = []



STDIN.read.split("\n").each do |row|
   arr = row.split(';')
   case ARGV[0] 
     when 'skoly'

       #GBIB;Biskupské gymnázium B. Balbína;;;;;;Orlické nábřeží 356/1,500 02,Hradec Králové,;;
       short = arr[0]
       long = arr[1]
       num = ''
       ul, psc, city, state  = arr[7].split(',')
       if ul =~ /^(.*?)\s([\d\/]*)$/
         ul = $1
         num = $2.strip
       end
       out.push({
                  'name'    =>  long,
                  'short'   =>  short,
                  'street'  =>  ul,
                  'num'     =>  num,
                  'city'    =>  city,
                  'psc'     =>  psc,
                  'state'   => state,
                })
   
     when 'lidi'
       #208;Bartošová;Aneta;6;6.A;sf0--;1.9.2000;č.p. 215,561 64,Mistrovice,;ZJJO;anet.bartosova@seznam.cz;
       next if arr[0] =~ /^%/
       id, last, first, grade, gradefull, flags, birth, addr, school, email = arr
       ul, psc, city, state  = addr.split(',')
       if ul =~ /^(.*?)\s([\d\/]*)$/
         ul = $1
         num = $2.strip
       end

       sex = flags[1] == 'f' ? 'female' : 'male'
       where_to_send = flags[1] == 'f' ? 'female' : 'male'
       where_to_send = flags[0] == 's' ? 'home' : 'school'
       
       out.push({
                "name"          => first,
                "last_name"     => last,
                "sex"           => sex,
                "birth"         => birth,
                "where_to_send" => where_to_send,
                "grade"         => gradefull,
                "finish_year"   => grade,#FIXME
                "annual"        => 29,   #FIXME
                "email"         => email ? "xxxxx"+email : nil, 
                "street"        => ul,
                "num"           => num,
                "city"          => city,
                "psc"           => psc,
                #!"user_id"       => 
                "school_id"    => school,
             })
     end
end

print YAML.dump(out)
