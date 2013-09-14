class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= User.new # guest user (not logged in)

    # anon
    # can :index, User

    can :new, SosnaSolver
    can :create, SosnaSolver
    can :create_tnx, SosnaSolver

    if user.user?
      can :user_index, SosnaSolution
      can :upload, SosnaSolution
      can :download, SosnaSolution
    end

    if user.org?
      can :index, SosnaSolution
      can :show, SosnaSolution
      can :download, SosnaSolution
      can :download_org, SosnaSolution
      can :upload, SosnaSolution
      can :upload_org, SosnaSolution
      can :update, SosnaSolution
      can :downall, SosnaSolution
      can :update_scores, SosnaSolution

      can :index, SosnaProblem
      can :show, SosnaProblem
      can :update, SosnaProblem
      can :new_round, SosnaProblem

      can :index, SosnaSolver
      can :show, SosnaSolver
      can :update, SosnaSolver

      can :index, SosnaSchool
      can :update, SosnaSchool

      can :index, SosnaConfig
      can :update, SosnaConfig
    end

    # pia
    can :index, :pium
    if user.admin?
      can :users, :pium
      can :user_role_change, :pium
    end
    if user.org? 
      #can :show, Giwi # mozna nekdy fungovalo
      #can :update, Giwi

      can :show, :giwi
      can :update, :giwi
    end
    # https://github.com/ryanb/cancan/wiki/Defining-Abilities
  end
end
