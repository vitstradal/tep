require 'prawn/measurement_extensions'
require 'pp'

o = {}
omm = {}

omm[:h] = (@opt[:h]||30).to_i
omm[:w] = (@opt[:w]||50).to_i

omm[:l] = (@opt[:l]||10).to_i
omm[:t] = (@opt[:t]||10).to_i

omm[:dx] = (@opt[:dx]||3).to_i
omm[:dy] = (@opt[:dy]||3).to_i

omm[:al] = (@opt[:al]||50).to_i
omm[:at] = (@opt[:at]||50).to_i

omm[:pl] = (@opt[:pl]||50).to_i
omm[:pt] = (@opt[:pt]||50).to_i

omm[:s] = (@opt[:s]||10).to_i

omm[:as] = (@opt[:ps]||10).to_i
omm[:ps] = (@opt[:as]||10).to_i

omm.each do |k,v|
  o[k] = v.mm
end
o[:s] = omm[:s]
o[:ps] = omm[:ps]
o[:as] = omm[:as]

pdf.font_size = o[:s]

#pdf.text pp(@opt).to_s if @dbg

ph =  pdf.margin_box.height
pw =  pdf.margin_box.width

def arrow(pdf, txt, x0, y0, x1, y1)

  u = 0.3.mm
  pdf.line [x0, y0], [x1, y1]

  pdf.line [x0 -u , y0 - u ], [x0 + u , y0 + u ]
  pdf.line [x0 -u , y0 + u ], [x0 + u , y0 - u ]

  pdf.line [x1 -u , y1 - u ], [x1 + u , y1 + u ] 
  pdf.line [x1 -u , y1 + u ], [x1 + u , y1 - u ] 

  pdf.stroke
  pdf.draw_text txt, :at => [(x0 +x1)/2 +0.5.mm, (y0+y1)/2 +0.5.mm]

end

def cross(pdf, o, omm)
   pdf.font_size = 10
   ph =  pdf.margin_box.height
   pw =  pdf.margin_box.width

   pwh = pw/2

   pdf.line_width 0.1.mm
   pdf.stroke_color 'a0a0a0'
   pdf.fill_color 'a0a0a0'

   [20.mm, ph/2, ph - 20.mm].each do |yy| 
     pdf.line [0, yy], [pw,yy]
     (0 .. pw).step(1.mm).each_with_index do |x,i|

        d = i%10==0  ? 6.mm : i%5==0  ? 3.mm : 2.mm
        pdf.line([x, yy], [x, yy + d])
     end
   end

   [20.mm, pw/2, pw - 20.mm].each do |xx| 
     pdf.line [xx, 0], [xx,ph]
     (0 .. ph).step(1.mm).each_with_index do |y,i|
        d = i%10==0  ? 6.mm : i%5==0  ? 3.mm : 2.mm
        pdf.line([xx, ph-y], [xx + d, ph-y])
     end
   end

   pdf.stroke

   if @envelope
     arrow pdf, "pt:#{omm[:pt]}", 10.mm + o[:pl], ph, 10.mm + o[:pl], ph - o[:pt]
     arrow pdf, "at:#{omm[:at]}", 10.mm + o[:al], ph, 10.mm + o[:al], ph - o[:at]

     arrow pdf, "pl:#{omm[:pt]}", 0.mm, ph - o[:pt] - 15.mm,  o[:pl], ph - o[:pt] - 15.mm
     arrow pdf, "al:#{omm[:at]}", 0.mm, ph - o[:at] - 15.mm,  o[:al], ph - o[:at] - 15.mm

     arrow pdf, "h:#{omm[:h]}", o[:w] - 10.mm + o[:al], ph - o[:at],  o[:w] - 10.mm + o[:al], ph - o[:at] - o[:h]
     arrow pdf, "w:#{omm[:w]}", o[:al], ph - o[:at] - o[:h] + 10.mm, o[:w] + o[:al],  ph - o[:at] - o[:h] + 10.mm

     arrow pdf, "as:#{omm[:s]}pt", o[:w]- 10.mm + o[:al], ph - o[:at], o[:w]- 10.mm + o[:al], ph - o[:at] - o[:as]
     arrow pdf, "ps:#{omm[:s]}pt", o[:w]- 10.mm + o[:pl], ph - o[:pt], o[:w]- 10.mm + o[:pl], ph - o[:pt] - o[:ps]

   else
     arrow pdf, "t:#{omm[:t]}", 40.mm, ph, 40.mm, ph - o[:t]
     arrow pdf, "l:#{omm[:l]}", 0, ph - 30.mm, o[:l],  ph - 30.mm
  
     arrow pdf, "h:#{omm[:h]}", 45.mm, ph - o[:t], 45.mm, ph - o[:t] - o[:h]
     arrow pdf, "w:#{omm[:w]}", o[:l], ph - 35.mm, o[:w] + o[:l],  ph - 35.mm
  
     arrow pdf, "s:#{omm[:s]}pt", 55.mm, ph - o[:t], 55.mm, ph - o[:t] - o[:s]
  
     arrow pdf, "dy:#{omm[:dy]}", 50.mm, ph - o[:t] - o[:h], 50.mm, ph - o[:t] - o[:h] - o[:dy]
     arrow pdf, "dx:#{omm[:dx]}", o[:l] + o[:w], ph - 30.mm, o[:l] + o[:w] + o[:dx] ,  ph - 30.mm
  
  end
  pdf.stroke_color '000000'
  pdf.fill_color '000000'
end

pdf.font_families.update( 'andulka' => { :normal => 'public/stylesheets/andulka/andulkabook-webfont.ttf',
                                         :bold   => 'public/stylesheets/andulka/andulkabook-bold-webfont.ttf',
                                       })
pdf.font 'andulka'

addrs = []
@solvers.each do |solver|
    school_name = nil
    if solver.where_to_send == 'home'
      street, city, psc, country = [ "#{solver.street} #{solver.num}", "#{solver.city}", "#{solver.psc} ", "#{solver.country}" ]
    else
      school = solver.school
      next if school.nil?
      school_name, street, city, psc, country = [ "#{school.name}",  "#{school.street} #{school.num}", "#{school.city}", "#{school.psc} ", "#{school.country}" ]
    end
    title = "#{solver.sex == 'female' ? "Řešitelka" : "Řešitel"} Pikomatu MFF UK"
    addrs.push( {full: solver.full_name, title: title, street: street, school_name: school_name, city:city, psc: psc, country: country})
end
@schools.each do |school|
    school_name, street, city, psc, country = [ "#{school.name}",  "#{school.street} #{school.num}", "#{school.city}", "#{school.psc} ", "#{school.country}" ]
    title = nil
    addrs.push({full: nil, title: title, street: street, school_name: school_name, city:city, psc: psc, country: country})
end

if @envelope
  #####################################################
  # nakresli obalky
  pdf.text "count: #{@solvers.size}" if @dbg
  addrs.each_with_index do |addr,index|
    cross pdf,o, omm if @dbg
    country_txt = country_code_to_txt(addr[:country])

    pdf.font_size = o[:ps]
    psc_y = 0 
    name = nil
    pdf.bounding_box([o[:al], ph - o[:at]],:width => o[:w], :height => o[:h] ) do
      pdf.text "<b>#{addr[:title]}</b>", :inline_format => true if addr[:title]
      pdf.text "#{addr[:full]}" if addr[:full]
      pdf.text  addr[:school_name] if addr[:school_name]
      pdf.text  addr[:street]
      psc_y = pdf.cursor
      pdf.text addr[:city]
      pdf.text "#{country_txt}" if ! country_txt.nil?
      pdf.stroke_bounds if @dbg
    end
    pdf.bounding_box([o[:al] - 20.mm, psc_y  - o[:h] + ph - o[:at]],:width => 20.mm - 1.mm, :height => o[:ps] ) do
      pdf.text addr[:psc] , :align => :right
      pdf.stroke_bounds if @dbg
    end

    pdf.font_size = o[:as]
    pdf.bounding_box([o[:pl], ph - o[:pt]],:width => o[:w], :height => o[:h] ) do
      pdf.text "<b>Pikomat MFF UK</b>", :inline_format => true, :align => :center
      pdf.text "KPMS MFF UK", :align => :center
      pdf.text "Sokolovská 83, 186 75 Praha 8", :align => :center
      pdf.text "Česká Republika", :align => :center if ! country_txt.nil?
      pdf.stroke_bounds if @dbg
    end
    pdf.start_new_page if index < addrs.size - 1 # not for last
  end
else
  #####################################################
  # nakresli stitky
  x = o[:l]
  y = ph - o[:t]
  cross pdf,o, omm if @dbg
  @solvers.each_with_index do |solver, index|
    country_txt = country_code_to_txt(solver.country)
    pdf.font_size = o[:s]
    pdf.bounding_box([x, y],:width => o[:w], :height => o[:h] ) do
      pdf.text "#{solver.sex == 'female' ? "Řešitelka" : "Řešitel"} Pikomatu MFF UK"
      pdf.text "#{solver.full_name}"
      pdf.text "#{solver.street} #{solver.num}"
      pdf.text "#{solver.psc} #{solver.city}"
      pdf.text "#{country_txt}" if ! country_txt.nil?
      pdf.stroke_bounds if @dbg
    end
    x += o[:w] + o[:dx]
    x,y = o[:l], y - o[:h] - o[:dy] if x + o[:w] > pw
    if y - o[:h] - o[:dy] < 0
     if index < solvers.size - 1  # not for last
        pdf.start_new_page
        x = o[:l]
        y =  ph - o[:t]
        cross pdf,o, omm if @dbg
      end
    end
  end
end

# vim: syn=ruby
