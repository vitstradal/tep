class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= User.new # guest user (not logged in)

    # https://github.com/ryanb/cancan/wiki/Defining-Abilities

    # public

    can :new, Sosna::Solver
    can :create, Sosna::Solver
    can :create_tnx, Sosna::Solver
    can :user_finish_registration, :pium

    # pia
    can :index, :pium
    can :faq, :pium

    if user.user?
      can :user_index, Sosna::Solution
      can :upload, Sosna::Solution
      can :download, Sosna::Solution
      can :download_corr, Sosna::Solution
    end

    if user.org?
      can :index, Sosna::Solution
      can :show, Sosna::Solution
      can :download, Sosna::Solution
      can :download_org, Sosna::Solution
      can :upload, Sosna::Solution
      can :upload_org, Sosna::Solution
      can :update, Sosna::Solution
      can :downall, Sosna::Solution
      can :update_scores, Sosna::Solution
      can :upload_corr, Sosna::Solution

      can :index, Sosna::Problem
      can :show, Sosna::Problem
      can :update, Sosna::Problem
      can :new_round, Sosna::Problem

      can :index, Sosna::Solver
      can :show, Sosna::Solver
      can :update, Sosna::Solver

      can :index, Sosna::School
      can :show, Sosna::School
      can :update, Sosna::School
      can :new, Sosna::School

      can :index, Sosna::School
      can :update, Sosna::School

      can :show,   :giwi
      can :update, :giwi

    end

    if user.admin?
      can :users,            :pium
      can :user,             :pium
      can :user_update,      :pium
      can :user_delete,      :pium
      can :user_action,      :pium
      can :user_role_change, :pium

      can :index,  Sosna::Config
      can :update, Sosna::Config
      can :delete, Sosna::Solver
      can :delete, Sosna::School
      can :delete, Sosna::Problem
    end

  end
end
