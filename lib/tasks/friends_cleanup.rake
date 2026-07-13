##
# Retence dat kvízového světa — viz navrh-kvizy-a-pratele.md §12.
# Pouštět z cronu cca jednou denně:
#   RAILS_ENV=production bundle exec rake friends:cleanup
namespace :friends do
  desc 'Smaž staré anonymní friendy (>1 rok neaktivní) a neověřené účty (>1 měsíc)'
  task cleanup: :environment do
    stale = Friend.where(user_id: nil)
                  .where('COALESCE(last_seen_at, updated_at) < ?', 1.year.ago)
    puts "friends:cleanup: mažu #{stale.count} anonymních friendů"
    stale.destroy_all

    User.where(confirmed_at: nil)
        .where('confirmation_sent_at < ?', 1.month.ago)
        .where('roles_mask IS NULL OR roles_mask = 0')
        .find_each do |u|
      next if Sosna::Solver.where(user_id: u.id).exists?
      next if u.participant
      Friend.where(user_id: u.id).each { |f| f.update!(user_id: nil) }
      puts "friends:cleanup: mažu neověřený účet #{u.email}"
      u.destroy
    end
  end
end
