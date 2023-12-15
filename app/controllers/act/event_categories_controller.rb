  ##
  #   Typ akce je škatulka zjednodušující práci s akcemi samotnými. Každá akce náleží právě jednomu typu akce.
  #   Předpokládaný počet typů akcí je 5-10
  #   Typem akce může být například Pikosobota, besídka, tábor, nebo pikobraní.
  #
class Act::EventCategoriesController < ActController
  ##
  #   GET  /act/event_categories/index/
  #
  # Zobrazí všechny typy akcí
  def index
    return render 'not_allowed', locals: { :desired => "read" } if ! can? :read, Act::EventCategory
  end

  ##
  #  GET /act/event_categories/code
  #
  # Zobrazí daný typ akce
  #
  # *Params*
  # code:: kód typu akce
  #
  def show
    return render 'not_allowed', locals: { :desired => "read" } if ! can? :read, Act::EventCategory

    @event_category = Act::EventCategory.find_by(code: params[:code])

    if @event_category.nil?
      return render 'not_found'
    end
  end
  
  ##
  #  GET /act/event_categories/new
  #
  # Formulář na nový typ akce
  #
  # *Provides*
  # @event_category:: typ akce
  #
  def new
    return render 'not_allowed', locals: { :desired => "create" } if ! can? :create, Act::EventCategory

    @event_category = Act::EventCategory.new
  end

  ##
  #  POST /act/event_categories/create
  #
  # Vytvoří nový typ akce
  #
  # *Params*
  # event_category_params[]:: parametry upravované akce
  #
  # *Redirect* @event_category
  def create
    return render 'not_allowed', locals: { :desired => "create" } if ! can? :create, Act::EventCategory

    @event_category = Act::EventCategory.new(event_category_params)

    if @event_category.save
      redirect_to @event_category
    else
      render :new, status: :unprocessable_entity
    end
  end

  ##
  #  GET /act/event_categories/:participant_id/edit
  #
  # Formulář na úpravu typu akce
  #
  # *Params*
  # code:: kód typu akce
  #
  # *Provides*
  # @event_category:: typ akce
  #
  def edit
    return render 'not_allowed', locals: { :desired => "update" } if ! can? :update, Act::EventCategory

    @event_category = Act::EventCategory.find_by(code: params[:code])
    
    if @event_category.nil?
      return render 'not_found'
    end
  end

  ##
  #  PATCH /act/event_categories/:participant_id/update
  #
  # Upraví typ akce
  #
  # *Params*
  # event_category_params[]:: parametry upravované akce
  #
  # *Redirect* act_event_categories_path
  def update
    return render 'not_allowed', locals: { :desired => "update" } unless can? :update, Act::EventCategory

    @event_category = Act::EventCategory.find_by(code: params[:code])

    if @event_category.nil?
      return render 'not_found'
    end

    unless Act::EventCategory::category_unique(params[:event_category][:code], params[:code])
      @event_category.errors.add(:event_category, "Kód akce musí být unikátní!")
      render :edit, status: :unprocessable_entity
      return
    end

    if @event_category.update(event_category_params)
      redirect_to act_event_categories_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  ##
  #  POST /act/event_categories/:participant_id/delete
  #
  # Smaže typ akce
  #
  # *Params*
  # code:: kód typu akce
  #
  # *Redirect* act_event_categories_path
  def delete
    return render 'not_allowed', locals: { :desired => "delete" } unless can? :delete, Act::EventCategory
  
    @event_category = Act::EventCategory.find_by(code: params[:code])

    if @event_category.nil?
      return render 'not_found'
    end

    @event_category.destroy

    redirect_to act_event_categories_path
  end

  ##
  #  POST /act/event_categories/jakna
  #
  # Ukáže uživatelskou dokumentaci k typům akcí
  #
  #
  def jakna
    @event_category = Act::EventCategory.new(code: "be", idx: 80, name: "Besídka", multi_day: true, 
    description: "Tradiční pikomatí akce konaná před Vánoci. Rozdávají se tam dárky.",
    visible: "ev", restrictions_electible: false, mass_spec_electible: true, activation_needed_default: "light")

  end

  private
    def event_category_params
      params.require(:event_category).permit!
    end
end
