  ##
  #   Typ akce je škatulka zjednodušující práci s akcemi samotnými. Každá akce náleží právě jednomu typu akce.
  #
class Act::EventCategoriesController < ActController
  ##
  #   GET  /act/event_categories/index/
  #
  # Zobrazí všechny typy akcí
  def index
    if !(can? :read, Act::EventCategory)
      render 'not_allowed', locals: { :desired => "read" }
      return
    end
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
    if !(can? :read, Act::EventCategory)
      render 'not_allowed', locals: { :desired => "read" }
      return
    end

    @event_category = Act::EventCategory.find_by(code: params[:code])

    if @event_category.nil?
      render 'not_found'
      return
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
    if !(can? :create, Act::EventCategory)
      render 'not_allowed', locals: { desired: "create" }
      return
    end

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
    if !(can? :create, Act::EventCategory)
      render 'not_allowed', locals: { desired: "create" }
      return
    end

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
    if !(can? :update, Act::EventCategory)
      render 'not_allowed', locals: { desired: "update" }
      return
    end

    @event_category = Act::EventCategory.find_by(code: params[:code])
    
    if @event_category.nil?
      render 'not_found'
      return
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
    if !(can? :update, Act::EventCategory)
      render 'not_allowed', locals: { desired: "update" }
      return
    end

    @event_category = Act::EventCategory.find_by(code: params[:code])

    if @event_category.nil?
      render 'not_found'
      return
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
    if !(can? :delete, Act::EventCategory)
      render 'not_allowed', locals: { desired: "delete" }
      return
    end
  
    @event_category = Act::EventCategory.find_by(code: params[:code])

    if @event_category.nil?
      render 'not_found'
      return
    end

    @event_category.destroy

    redirect_to act_event_categories_path
  end

  private
    def event_category_params
      params.require(:event_category).permit!
    end
end
