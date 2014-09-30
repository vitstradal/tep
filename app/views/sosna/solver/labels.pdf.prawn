require 'prawn/measurement_extensions'
b = false
b = true

h = 30.mm
w = 55.mm
dx = 3.mm
dy = 3.mm

l = 10.mm
t = 10.mm


ph =  pdf.margin_box.height
pw =  pdf.margin_box.width

x = l
y =  ph - t

pdf.stroke_axis if b

pdf.font_families.update( 'andulka' => { :normal => 'public/stylesheets/andulka/andulkabook-webfont.ttf' } )
pdf.font 'andulka'


@solvers.each do |solver|
  pdf.bounding_box([x, y],:width => w, :height => h ) do
    pdf.text "#{solver.sex == 'f' ? "Řešitelka" : "Řešitel"} Pikomatu MFF UK"
    pdf.text "#{solver.full_name}"
    pdf.text "#{solver.street} #{solver.num}"
    pdf.text "#{solver.psc} #{solver.city}"
    pdf.stroke_bounds if b
  end
  x += w + dx
  x,y = l,y-h-dy if x + w + l  > pw
end
