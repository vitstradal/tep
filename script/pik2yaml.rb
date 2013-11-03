#!/usr/bin/env ruby

require 'yaml'

out = []

def skoly_line(arr)
     #GBIB;Biskupské gymnázium B. Balbína;;;;;;Orlické nábřeží 356/1,500 02,Hradec Králové,;;
     short = arr[0]
     long = arr[1]
     num = ''
     ul, psc, city, state  = arr[7].split(',')
     if ul =~ /^(.*?)\s([\d\/]*)$/
       ul = $1
       num = $2.strip
     end
     return {
                'name'    =>  long,
                'short'   =>  short,
                'street'  =>  ul,
                'num'     =>  num,
                'city'    =>  city,
                'psc'     =>  psc,
                'state'   => state,
              }
end
   
def lidi_line(arr)
       #208;Bartošová;Aneta;6;6.A;sf0--;1.9.2000;č.p. 215,561 64,Mistrovice,;ZJJO;anet.bartosova@seznam.cz;
       id, last, first, gradenum, grade, flags, birth, addr, school, email = arr
       ul, psc, city, state  = addr.split(',')
       if ul =~ /^(.*?)\s([-\d\/]*[a-z]?)$/i
         ul = $1.strip
         num = $2.strip
       end

       sex = flags[1] == 'f' ? 'female' : 'male'
       where_to_send = flags[1] == 'f' ? 'female' : 'male'
       where_to_send = flags[0] == 's' ? 'home' : 'school'
       gradenum = nil if gradenum == '?'
       
       return {
                "name"          => first,
                "last_name"     => last,
                "sex"           => sex,
                "birth"         => birth,
                "where_to_send" => where_to_send,
                "grade"         => grade,
                "grade_num"     => gradenum,#FIXME
                "annual"        => 29,   #FIXME
                "email"         => email ? email : nil, 
                "street"        => ul,
                "num"           => num,
                "city"          => city,
                "psc"           => psc,
                #!"user_id"       => 
                "school_short"   => school,
       }
end

case ARGV[0] 
     when 'skoly'
       STDIN.read.split("\n").each do |row|
        out.push(skoly_line(row.split(';')))
       end
     when 'lidi'
      STDIN.read.split("\n").each do |row|
        next if row =~ /^%/
        out.push(lidi_line(row.split(';')))
      end
end

print YAML.dump(out)
