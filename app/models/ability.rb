##
# Třída definující, co který uživatel může. Přístupová práva jsou založena na příslušnosti uživatele ve skupině.
#
class Ability
  include CanCan::Ability

  ##
  # *Params*
  # user:: viz kupiny u {User}[rdoc-ref:User]. Viz source co přesně kdo může.
  # 
  # Příklad:
  #  can :add, Infrom # v controlleru `Inform` může volat metodu `add`
  def initialize(user)

    user ||= User.new # guest user (not logged in)

    # https://github.com/ryanb/cancan/wiki/Defining-Abilities
    # public

    can :add, Inform
    can :tnx, Inform

    can :new, Sosna::Solver
    can :new_bonus, Sosna::Solver
    can :create, Sosna::Solver
    can :create_tnx, Sosna::Solver
    can :user_finish_registration, :tep
    can :access,           :tep

    # tep
    can :index, :tep
    can :faq, :tep
    can :csrf, :tep
    can :die, :tep
    #can :error, :tep


    # oauth
    can :me, :credentials

    can :index, :aesop
    #can :index, :aesop
    #can :update, :giwi, if: :can_update?

    # jabber
    #can :auth, Jabber
    #can :prebind, Jabber

    if user.user?
      can :user_index, Sosna::Solution
      can :user_bonus, Sosna::Solution
      can :upload, Sosna::Solution
      can :upload_confirm_file, Sosna::Solution
      can :get_confirm_file, Sosna::Solution
      can :download, Sosna::Solution
      can :download_rev, Sosna::Solution

      can :user_solver_confirm, Sosna::Solver
      can :update_confirm, Sosna::Solver
      can :info, :tepna
    end

    if user.org?
      can :index, Inform
      can :pokusy, :tep
      can :view_error, :tep

      can :index, Sosna::Solution
      can :show, Sosna::Solution
      can :lidi, Sosna::Solution
      can :vysl_pik,  Sosna::Solution
      can :vysl_wiki, Sosna::Solution
      can :download, Sosna::Solution
      can :download_org, Sosna::Solution
      can :upload, Sosna::Solution
      can :upload_org, Sosna::Solution
      can :update, Sosna::Solution
      can :downall, Sosna::Solution
      can :upload_rev, Sosna::Solution
      can :user_index_org, Sosna::Solution
      can :rocnik, Sosna::Solution

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

      can :index, Sosna::Config

      can :sklad, Priklady

      can :status, :klep

    end

    # master-org, or more-org, 
    if user.morg?

      can :new_round, Sosna::Problem
      can :del, Inform
      can :delform, Inform

      can :update, Sosna::Solver
      can :update, Sosna::School

      can :update, Sosna::Problem

      can :update_papers, Sosna::Solution
      can :update_penalisations, Sosna::Solution
      can :update_results, Sosna::Solution

      can :get_confirm_files, Sosna::Solution

    end

    if user.admin?

      can :aesop, Sosna::Solver
      can :aesop_index, Sosna::Solver
      can :aesop_annual, Sosna::Solver
      can :aesop_create, Sosna::Solver
      can :aesop_refresh_index, Sosna::Solver

      can :confirm_none_to_next, Sosna::Solver

      can :delete, Sosna::Solver
      can :spam, Sosna::Solver
      can :do_spam, Sosna::Solver
      can :delete, Sosna::School
      can :delete, Sosna::Problem
      can :resign, Sosna::Solution
      can :nosign, Sosna::Solution

      can :users,            :tep
      can :user,             :tep
      can :user_new,         :tep
      can :user_update,      :tep
      can :user_delete,      :tep
      can :user_action,      :tep
      can :user_role_change, :tep


      can :index,  Sosna::Config
      can :update, Sosna::Config

      #can :new,  Jabber
      #can :update, Jabber
      #can :delete, Jabber
    end

    # Wikis
    Giwi.giwis.each_value do |giwi|
      auth_name =  Giwi.auth_name(giwi.name)
      can :show,   auth_name if !giwi.read.nil?   && (giwi.read   == :anon || user.has_role?(giwi.read))
      can :update, auth_name if !giwi.update.nil? && (giwi.update == :anon || user.has_role?(giwi.update))
    end

  end
end
