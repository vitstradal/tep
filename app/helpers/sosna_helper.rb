require 'resolv'
require 'iconv'

module SosnaHelper

  #  like link_to(text, action: :show) for obj
  # but if obj.nil? show only text
  def link_to_show(text, obj_id)
    if obj_id
      link_to text, :action => 'show', :id =>  obj_id
    else
      text
    end
  end
  def deadline_time(cfg, round, ignore_show = false)
    if ! ignore_show
      s = cfg["show#{round}".to_sym]
      return nil if ! s || s != 'yes'
    end
    t = cfg["deadline#{round}".to_sym]
    return nil if ! t
    return Time.parse(t) + 1.day - 1
  end

  def add_alert(msg)
    flash[:alerts] ||= []
    flash[:alerts].push(msg)
  end

  def add_success(msg)
    flash[:success] ||= []
    flash[:success].push(msg)
  end

  def email_valid_mx_record?(email)
      mail_servers = Resolv::DNS.open.getresources(email.split('@').last, Resolv::DNS::Resource::IN::MX)
      return false if mail_servers.empty?
      true
  end

  def translit(str)
    Iconv.iconv('ascii//translit', 'utf-8', str).join
  end
  def self.translit(str)
    Iconv.iconv('ascii//translit', 'utf-8', str).join
  end

  def strcoll(a,b)
    FFILocale::strcoll(a, b) 
  end

  def strcollf(a,b)
    ret = FFILocale::strcoll(a, b) 
    return ret == 0 ? false : ret
  end

end
