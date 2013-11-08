module Sosna::SchoolHelper

 def form_error(obj, *attrs)
   errors = []
   attrs.each {|a| errors.concat(obj.errors.get(a) || [] ) }
   return if errors.empty?
   txt = errors.join(", ")
   return content_tag(:span, txt , class: 'help-inline');
 end

 def form_error_class(obj, *attrs)
   attrs.each  do |a|
     return 'control-group error' if ! obj.errors.get(a).nil?
   end
   return 'control-group'
 end

end
