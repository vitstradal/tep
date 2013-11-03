module SosnaHelper

  def link_to_show(text, obj)
    if obj 
      link_to text, :action => 'show', :id =>  obj.id
    else
      text
    end
    
  end
end
