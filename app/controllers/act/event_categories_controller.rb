class Act::EventCategoriesController < ActController
  def index
    if !(can? :read, Act::EventCategory)
      render 'not_allowed', locals: { :desired => "read" }
      return
    end
  end

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
  
  def new
    if !(can? :create, Act::EventCategory)
      render 'not_allowed', locals: { desired: "create" }
      return
    end

    @event_category = Act::EventCategory.new
  end

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
