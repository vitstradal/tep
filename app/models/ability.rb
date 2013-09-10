class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= User.new # guest user (not logged in)

    # anon
    can :new, SosnaSolver
    can :create, SosnaSolver
    can :create_tnx, SosnaSolver

    if user.user?
      can :index, SosnaSolution
      can :user_upload, SosnaSolution
      can :download, SosnaSolution
    end

    if user.org?
      can :index, SosnaSolution
      can :show, SosnaSolution
      can :update, SosnaSolution

      can :index, SosnaProblem
      can :show, SosnaProblem
      can :update, SosnaProblem

      can :index, SosnaSolver
      can :show, SosnaSolver
      can :update, SosnaSolver

      can :index, SosnaSchool
      can :update, SosnaSchool

      can :index, SosnaConfig
      can :update, SosnaConfig
    end

    # pia
    if user.admin?
      can :anon, :pia
      can :anon, :sosna
    end
    # https://github.com/ryanb/cancan/wiki/Defining-Abilities
  end
end
