class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= User.new # guest user (not logged in)

    # anon
    # can :index, User

    can :new, Sosna::Solver
    can :create, Sosna::Solver
    can :create_tnx, Sosna::Solver
    can :user_finish_registration, :pium

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

    end

    # pia
    can :index, :pium
    can :faq, :pium
    if user.admin?
      can :users, :pium
      can :user_role_change, :pium

      can :index, Sosna::Config
      can :update, Sosna::Config
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
