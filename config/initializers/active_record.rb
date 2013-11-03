class ActiveRecord::Base
  # write ur common base code here

  def self.find_or_new(id)
    if id.nil? 
      return new
    else
      return find(id)
    end
  end

  def next(delta = 1)
    self.class.find_by_id id + delta
  end

  def self.update_or_create(hash)
    id = hash[:id]
    if id.nil?
      return create(hash)
    else
      return find(id).update(hash)
    end
  end
end
