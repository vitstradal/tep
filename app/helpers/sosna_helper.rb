module SosnaHelper

  #  like link_to(text, action: :show) for obj
  # but if obj.nil? show only text
  def link_to_show(text, obj)
    if obj
      link_to text, :action => 'show', :id =>  obj.id
    else
      text
    end
  end

  def add_alert(msg)
    flash[:alerts] ||= []
    flash[:alerts].push(msg)
  end

  def add_success(msg)
    flash[:success] ||= []
    flash[:success].push(msg)
  end

end
