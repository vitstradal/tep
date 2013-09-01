
class  Sosna::SosnaBase < ActiveRecord::Base
  def find_or_new(id)
    return find(id) || new
  end

  def update_or_create(hash)
    id = hash[:id]
    if id.nil?
      return create(hash)
    else
      find(id).update(hash)
    end
  end
end
