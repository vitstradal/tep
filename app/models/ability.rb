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

    #wikis
    Giwi.giwis.each_value do |giwi|
      auth_name =  Giwi.auth_name(giwi.name)
      can :show,   auth_name if !giwi.read.nil?   && (giwi.read   == :anon || user.has_role?(giwi.read))
      can :update, auth_name if !giwi.update.nil? && (giwi.update == :anon || user.has_role?(giwi.update))

      print "can :update, #{auth_name}\n" if !giwi.update.nil? && user.has_role?(giwi.update)
      print "can :read, #{auth_name}\n" if !giwi.read.nil? && user.has_role?(giwi.read)
    end
    #can :update, :giwi, if: :can_update?

    if user.user?
      can :user_index, Sosna::Solution
      can :upload, Sosna::Solution
      can :download, Sosna::Solution
      can :download_rev, Sosna::Solution
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
      can :upload_rev, Sosna::Solution

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
