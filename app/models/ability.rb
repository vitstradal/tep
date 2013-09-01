class Ability
  include CanCan::Ability

  def initialize(user)

    # Define abilities for the passed in user here. For example:

    user ||= User.new # guest user (not logged in)
    if user.admin?
        can :user, :sosna
        can :org, :sosna
        can :admin, :sosna
        can :admin, :pia
    end

    if user.org?
        can :admin, :sosna
        can :admin, :pia
    end

    if user.user?
        can :user, :sosna
    end

    can :anon, :pia
    can :anon, :sosna

    # See the wiki for details:
    # https://github.com/ryanb/cancan/wiki/Defining-Abilities
  end
end
