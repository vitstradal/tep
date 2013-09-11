class SosnaConfigController < SosnaController

  def index
    load_config
  end

  def update
    config = params[:config]
    config.each_pair do |k,v|
        cfg = SosnaConfig.where(:key =>  k).first
        if cfg.nil?
          SosnaConfig.create :key => k, :value => v
        else 
          cfg.value = v
          cfg.save
        end
                
    end
    redirect_to :sosna_configs
  end

end
