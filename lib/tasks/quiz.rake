##
# Pomocné tasky pro kvízy (viz navrh-kvizy-a-pratele.md)
namespace :quiz do
  desc 'Založ testovací anketku /quiz/testquiz (idempotentní)'
  task testquiz: :environment do
    quiz = Quiz.find_or_create_by!(name: 'testquiz') do |q|
      q.quiz_type = 'poll'
      q.title = 'Testovací anketka'
      q.data = { 'question' => 'Napiš, co tě napadne' }
    end
    puts "quiz:testquiz: #{quiz.name} (id #{quiz.id}) — /quiz/testquiz"
  end
end
