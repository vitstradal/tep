##
# Pomocné tasky pro kvízy (viz navrh-kvizy-a-pratele.md)
namespace :quiz do
  desc 'Založ testovací anketku /quiz/testquiz (idempotentní)'
  task testquiz: :environment do
    quiz = Quiz.find_or_create_by!(name: 'testquiz') do |q|
      q.quiz_type = 'poll'
      q.title = 'Testovací anketka'
      q.data = { 'question' => 'Napiš, co tě napadne', 'public_results' => true }
    end
    # zapni veřejné výsledky i při opakovaném spuštění na existujícím záznamu
    unless quiz.results_public?
      quiz.update!(data: (quiz.data || {}).merge('public_results' => true))
    end
    puts "quiz:testquiz: #{quiz.name} (id #{quiz.id}) — /quiz/testquiz"
  end

  desc 'Založ kvíz přednášky logické obvody (idempotentní; sběr řešení z pub/prednasky)'
  task logicke_obvody: :environment do
    quiz = Quiz.find_or_create_by!(name: 'logicke-obvody') do |q|
      q.quiz_type = 'quiz'
      q.title = 'Logické obvody — kvízy'
      # správnost vyhodnocuje org lokálně (kontrola.html), server jen sbírá
    end
    puts "quiz:logicke_obvody: #{quiz.name} (id #{quiz.id})"
  end

  ##
  # Obecná utilita: založí (nebo upraví) libovolný kvíz. Idempotentní.
  # ENV (ne rake args — kvůli mezerám v názvu):
  #   NAME=<identifikátor do URL>   (povinné, /quiz/<name>)
  #   TYPE=poll|quiz|advent         (výchozí poll)
  #   TITLE=<lidský název>          (výchozí = NAME)
  #   PUBLIC=1                      (zveřejní výsledky; jinak vidí jen org)
  # Příklad:
  #   NAME=tabor2026 TITLE='Tábor 2026 A' rake quiz:create RAILS_ENV=production
  desc "Založ/uprav kvíz: NAME=… [TYPE=poll|quiz|advent] [TITLE=…] [PUBLIC=1] (idempotentní)"
  task create: :environment do
    name = ENV['NAME'].to_s.strip
    abort 'Chybí NAME (např. NAME=tabor2026)' if name.empty?
    type = (ENV['TYPE'] || 'poll').strip
    unless %w[quiz advent poll].include?(type)
      abort "Neplatný TYPE=#{type} (povolené: quiz, advent, poll)"
    end
    quiz = Quiz.find_or_initialize_by(name: name)
    quiz.quiz_type = type
    quiz.title = ENV['TITLE'].to_s.strip.empty? ? name : ENV['TITLE'].strip
    quiz.data = (quiz.data || {}).merge('public_results' => true) if ENV['PUBLIC'] == '1'
    quiz.save!
    flag = quiz.results_public? ? ', public' : ''
    puts "quiz:create: #{quiz.name} (id #{quiz.id}, #{quiz.quiz_type}#{flag}) — /quiz/#{quiz.name}"
  end
end
