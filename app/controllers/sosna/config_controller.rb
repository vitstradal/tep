class Sosna::ConfigController < SosnaController

  def index
    load_config
  end

  def update
    config = params[:config]
    config.each_pair do |k,v|
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
