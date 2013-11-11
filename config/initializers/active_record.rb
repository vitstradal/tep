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
    return nil if id.nil?

    if delta > 0
      self.class.where('id > ?', id).minimum(:id)
    else
      self.class.where('id < ?', id).maximum(:id)
    end
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
