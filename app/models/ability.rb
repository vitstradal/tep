class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= User.new # guest user (not logged in)

    # https://github.com/ryanb/cancan/wiki/Defining-Abilities

    # public

    can :new, Sosna::Solver
    can :create, Sosna::Solver
    can :create_tnx, Sosna::Solver
    can :user_finish_registration, :tep
    can :access,           :tep

    # tep
    can :index, :tep
    can :faq, :tep
    can :csrf, :tep
    can :die, :tep
    can :error, :tep

    can :index, :aesop
    #can :index, :aesop

    #can :update, :giwi, if: :can_update?

    if user.user?
      can :user_index, Sosna::Solution
      can :upload, Sosna::Solution
      can :download, Sosna::Solution
      can :download_rev, Sosna::Solution
    end

    if user.org?
      can :pokusy, :tep

      can :index, Sosna::Solution
      can :show, Sosna::Solution
      can :download, Sosna::Solution
      can :download_org, Sosna::Solution
      can :upload, Sosna::Solution
      can :upload_org, Sosna::Solution
      can :update, Sosna::Solution
      can :downall, Sosna::Solution
      can :upload_rev, Sosna::Solution
      can :user_index_org, Sosna::Solution

      can :index, Sosna::Problem
      can :show, Sosna::Problem

      can :index, Sosna::Solver
      can :show, Sosna::Solver
      can :dup, Sosna::Solver
      can :labels, Sosna::Solver
      can :tep_emails, Sosna::Solver

      can :index, Sosna::School
      can :show, Sosna::School
      can :new, Sosna::School

      can :index, Sosna::School
      can :update_scores, Sosna::Solution

    end

    # master-org, or more-org, 
    if user.morg?

      can :new_round, Sosna::Problem

      can :update, Sosna::Solver
      can :update, Sosna::School

      can :update, Sosna::Problem

      can :update_papers, Sosna::Solution
      can :update_penalisations, Sosna::Solution
      can :update_results, Sosna::Solution

    end

    if user.admin?

      can :delete, Sosna::Solver
      can :delete, Sosna::School
      can :delete, Sosna::Problem

      can :users,            :tep
      can :user,             :tep
      can :user_new,         :tep
      can :user_update,      :tep
      can :user_delete,      :tep
      can :user_action,      :tep
      can :user_role_change, :tep

      can :index,  Sosna::Config
      can :update, Sosna::Config
    end

    # Wikis
    Giwi.giwis.each_value do |giwi|
      auth_name =  Giwi.auth_name(giwi.name)
      can :show,   auth_name if !giwi.read.nil?   && (giwi.read   == :anon || user.has_role?(giwi.read))
      can :update, auth_name if !giwi.update.nil? && (giwi.update == :anon || user.has_role?(giwi.update))
    end

  end
end
