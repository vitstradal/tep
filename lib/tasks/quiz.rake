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
end
