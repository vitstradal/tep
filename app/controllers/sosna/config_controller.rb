##
# Controller pro změnu běžné konfigurace
#
class Sosna::ConfigController < SosnaController

  ##
  #  GET /sosna/config
  #
  # viz helper `load_config` {rdoc}[rdoc-ref:ApplicationHelper.load_config]
  def index
    load_config
  end

  ##
  #  POST /sosna/config/update
  #
  # config[]:: všechny zadané parametry budou uloženy do tabulky `sosna_configs`
  def update
    config = params[:config]
    config.each_pair do |k,v|

        if k =~ /^deadline\d+$/
          v = Time.new(v[:year], v[:month], v[:day]).strftime('%Y-%m-%d')
        end

        cfg = Sosna::Config.where(:key =>  k).first
        if cfg.nil?
          Sosna::Config.create :key => k, :value => v
        else 
          cfg.value = v
          cfg.save
        end
                
    end
    redirect_to :sosna_configs
  end

end
