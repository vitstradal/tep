# Kvízy, adventomat a přátelé Pikomatu — implementační plán

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementovat specifikaci `navrh-kvizy-a-pratele.md` — anonymní kvízové identity (`friends`), kvízy (`quizzes`, `quiz_answers`), registraci přítele Pikomatu s mailovým ověřením, hlavičkový widget a trvalé přihlášení.

**Architecture:** Tři nové tabulky + top-level modely `Friend`, `Quiz`, `QuizAnswer` (bez namespace, jako `Inform`). Nový `FriendController` (identita/registrace) a `QuizController` (odpovědi/výsledkovka). Identita odpovědí vždy přes `friend_id`; ověření přes existující Devise `:confirmable`. Frontend: úprava `application.html.erb` + `public/javascripts/tep.js` (localStorage klíč `friend`).

**Tech Stack:** Rails 7.2, Devise 4.9 (confirmable), cancancan, role_model, jQuery 1.10, minitest (`ActionController::TestCase`).

## Global Constraints

- Prostředí pro každý shell (bez toho běží ruby 3.4.7 a nic nefunguje):
  ```sh
  export PATH=$HOME/.rvm/gems/ruby-3.2.1/bin:$HOME/.rvm/gems/ruby-3.2.1@global/bin:$HOME/.rvm/rubies/ruby-3.2.1/bin:$PATH \
         GEM_HOME=$HOME/.rvm/gems/ruby-3.2.1 \
         GEM_PATH=$HOME/.rvm/gems/ruby-3.2.1:$HOME/.rvm/gems/ruby-3.2.1@global
  ```
- Testy: `RAILS_ENV=test bundle exec rails test [soubor]`. **Baseline: celá suite má 4 pre-existující failures v `test/functional/tep_controller_test.rb` (user_change_email)** — nové tasky je nesmí zvýšit; nové testovací soubory musí mít 0 failures.
- Testovací DB je sqlite3, staví se ze `db/schema.rb` (migrace od nuly nejedou). Po přidání migrace 033 se **ručně** edituje `db/schema.rb` (verze + tabulky s PG typy `timestamptz`/`jsonb`); NIKDY nespouštět `db:migrate` na sqlite s následným commitem přegenerovaného schema.rb.
- Pořadí rolí `roles :admin, :org, :user, :guest, :sklep, :morg, :jabber` se NESMÍ měnit; žádná nová role se nezavádí.
- Komentáře a texty česky, RDoc styl `##` jako v okolním kódu. Commit messages česky, malá písmena, bez Co-Authored-By.
- Modely dědí z `ActiveRecord::Base` (styl repa).

---

### Task 1: Migrace 033 + modely Friend, Quiz, QuizAnswer

**Files:**
- Create: `db/migrate/033_create_friends_and_quizzes.rb`
- Modify: `db/schema.rb` (verze 32 → 33, přidat 3 tabulky)
- Modify: `config/initializers/sqlite3_timestamptz.rb` (přidat alias `jsonb` → `json`)
- Create: `app/models/friend.rb`, `app/models/quiz.rb`, `app/models/quiz_answer.rb`
- Modify: `app/models/user.rb` (přidat `has_one :friend` k řádku 63)
- Test: `test/unit/friend_test.rb`, `test/unit/quiz_test.rb`

**Interfaces:**
- Produces: `Friend` (`uuid`, `nick`, `user_id`, `hidden`, `last_seen_at`; metody `status` → `'anonymous'|'unverified'|'verified'`, `discriminator` → 2 hex znaky, `display_nick`), `Quiz` (`name` unique, `quiz_type`, `subtype`, `title`, `opens_on`, `closes_on`, `data`; metody `open?(today)`, `question_open?(question_no, today)`), `QuizAnswer` (`quiz_id`, `friend_id`, `question_no`, `answer`, `data`), `user.friend`.

- [ ] **Step 1: Napsat migraci**

```ruby
# db/migrate/033_create_friends_and_quizzes.rb
##
# Kvízy, adventomat a přátelé Pikomatu — viz navrh-kvizy-a-pratele.md
class CreateFriendsAndQuizzes < ActiveRecord::Migration[7.2]
  def change
    create_table :friends do |t|
      t.text :uuid, null: false
      t.text :nick, null: false
      t.bigint :user_id
      t.boolean :hidden, default: false
      t.timestamptz :last_seen_at
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :friends, :uuid, unique: true
    add_index :friends, :user_id, unique: true

    create_table :quizzes do |t|
      t.text :name, null: false
      t.text :quiz_type
      t.text :subtype
      t.text :title
      t.date :opens_on
      t.date :closes_on
      t.jsonb :data
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :quizzes, :name, unique: true

    create_table :quiz_answers do |t|
      t.bigint :quiz_id, null: false
      t.bigint :friend_id, null: false
      t.integer :question_no
      t.text :answer
      t.jsonb :data
      t.timestamptz :created_at, null: false
      t.timestamptz :updated_at, null: false
    end
    add_index :quiz_answers, [:quiz_id, :question_no, :friend_id], unique: true
  end
end
```

- [ ] **Step 2: Rozšířit sqlite initializer o jsonb**

V `config/initializers/sqlite3_timestamptz.rb` doplnit do `class_eval` bloku:

```ruby
    def jsonb(*names, **options)
      names.each { |name| column(name, :json, **options) }
    end
```

- [ ] **Step 3: Ručně dopsat tabulky do `db/schema.rb`**

Změnit `define(version: 32)` na `define(version: 33)` a před `create_table "informs"` vložit (PG typy, styl souboru):

```ruby
  create_table "friends", force: :cascade do |t|
    t.text "uuid", null: false
    t.text "nick", null: false
    t.bigint "user_id"
    t.boolean "hidden", default: false
    t.timestamptz "last_seen_at"
    t.timestamptz "created_at", null: false
    t.timestamptz "updated_at", null: false
    t.index ["user_id"], name: "index_friends_on_user_id", unique: true
    t.index ["uuid"], name: "index_friends_on_uuid", unique: true
  end

  create_table "quiz_answers", force: :cascade do |t|
    t.bigint "quiz_id", null: false
    t.bigint "friend_id", null: false
    t.integer "question_no"
    t.text "answer"
    t.jsonb "data"
    t.timestamptz "created_at", null: false
    t.timestamptz "updated_at", null: false
    t.index ["quiz_id", "question_no", "friend_id"], name: "index_quiz_answers_on_quiz_id_and_question_no_and_friend_id", unique: true
  end

  create_table "quizzes", force: :cascade do |t|
    t.text "name", null: false
    t.text "quiz_type"
    t.text "subtype"
    t.text "title"
    t.date "opens_on"
    t.date "closes_on"
    t.jsonb "data"
    t.timestamptz "created_at", null: false
    t.timestamptz "updated_at", null: false
    t.index ["name"], name: "index_quizzes_on_name", unique: true
  end
```

Pozn.: sqlite si testovací DB přegeneruje sám (maintain_test_schema při `rails test`).

- [ ] **Step 4: Napsat failing unit testy**

```ruby
# test/unit/friend_test.rb
require 'test_helper'

class FriendTest < ActiveSupport::TestCase
  test "create generates uuid and strips nick" do
    f = Friend.create!(nick: '  Petr  ')
    assert f.uuid.present?
    assert_equal 'Petr', f.nick
  end

  test "uuid must be unique" do
    f = Friend.create!(nick: 'Petr')
    dup = Friend.new(nick: 'Jiny', uuid: f.uuid)
    assert_not dup.valid?
  end

  test "user_id unique, one friend per user" do
    u = User.new(email: 'f@x.cz', password: 'password123')
    u.skip_confirmation!
    u.save!
    Friend.create!(nick: 'Petr', user: u)
    dup = Friend.new(nick: 'Jiny', user: u)
    assert_not dup.valid?
  end

  test "status ladder" do
    assert_equal 'anonymous', Friend.create!(nick: 'A').status

    u = User.new(email: 'g@x.cz', password: 'password123')
    u.save!  # neověřený
    f = Friend.create!(nick: 'B', user: u)
    assert_equal 'unverified', f.status

    u.confirm
    assert_equal 'verified', f.reload.status
  end

  test "discriminator is short and stable" do
    f = Friend.create!(nick: 'Petr')
    assert_match(/\A[0-9a-f]{2}\z/, f.discriminator)
    assert_equal f.discriminator, f.discriminator
  end
end
```

```ruby
# test/unit/quiz_test.rb
require 'test_helper'

class QuizTest < ActiveSupport::TestCase
  test "name must be unique" do
    Quiz.create!(name: 'advent-2026', quiz_type: 'advent')
    assert_not Quiz.new(name: 'advent-2026').valid?
  end

  test "open? respects window" do
    q = Quiz.new(name: 'q', opens_on: Date.new(2026, 12, 1), closes_on: Date.new(2026, 12, 24))
    assert_not q.open?(Date.new(2026, 11, 30))
    assert q.open?(Date.new(2026, 12, 1))
    assert q.open?(Date.new(2026, 12, 24))
    assert_not q.open?(Date.new(2026, 12, 25))
  end

  test "open? without window is always open" do
    assert Quiz.new(name: 'q').open?
  end

  test "advent question opens day by day" do
    q = Quiz.new(name: 'a', quiz_type: 'advent', opens_on: Date.new(2026, 12, 1), closes_on: Date.new(2026, 12, 31))
    assert q.question_open?(1, Date.new(2026, 12, 1))
    assert_not q.question_open?(2, Date.new(2026, 12, 1))
    assert q.question_open?(24, Date.new(2026, 12, 24))
  end

  test "non-advent question needs only open window" do
    q = Quiz.new(name: 'k', quiz_type: 'quiz')
    assert q.question_open?(5)
  end

  test "one answer per quiz, question and friend" do
    q = Quiz.create!(name: 'k')
    f = Friend.create!(nick: 'Petr')
    QuizAnswer.create!(quiz: q, friend: f, question_no: 1, answer: '42')
    dup = QuizAnswer.new(quiz: q, friend: f, question_no: 1, answer: '43')
    assert_not dup.valid?
  end
end
```

- [ ] **Step 5: Spustit testy — musí failnout** (`NameError: uninitialized constant Friend`)

Run: `RAILS_ENV=test bundle exec rails test test/unit/friend_test.rb test/unit/quiz_test.rb`

- [ ] **Step 6: Implementovat modely**

```ruby
# app/models/friend.rb
##
# Přítel Pikomatu — identita v kvízovém světě (viz navrh-kvizy-a-pratele.md).
#
# uuid drží prohlížeč v localStorage; dokud user_id je NULL, jde o anonymního
# přítele. Po registraci se doplní user_id (unikátní — každý uživatel má
# právě jednoho přítele). Nick je jediný zdroj pravdy pro výsledkovky,
# i po registraci.
class Friend < ActiveRecord::Base
  belongs_to :user, optional: true
  has_many :quiz_answers, dependent: :destroy

  validates :uuid, presence: true, uniqueness: true
  validates :nick, presence: true, length: { maximum: 40 }
  validates :user_id, uniqueness: true, allow_nil: true

  before_validation do
    self.uuid ||= SecureRandom.uuid
    self.nick = nick.to_s.strip
  end

  ##
  # 'anonymous' | 'unverified' | 'verified' — viz žebřík identit v návrhu
  def status
    return 'anonymous' if user.nil?
    user.confirmed_at ? 'verified' : 'unverified'
  end

  ##
  # Krátký veřejný rozlišovač kolizí nicků (Petr ·a3). Hash z uuid,
  # ne uuid samotné, aby neuniklo.
  def discriminator
    Digest::SHA1.hexdigest(uuid.to_s)[0, 2]
  end

  ##
  # Nick pro výsledkovku (moderace: skrytý friend je 'anonym')
  def display_nick
    hidden ? 'anonym' : nick
  end
end
```

```ruby
# app/models/quiz.rb
##
# Kvíz, adventní kalendář nebo anketa (viz navrh-kvizy-a-pratele.md).
# quiz_type:: 'quiz' | 'advent' | 'poll'
# name:: čitelný identifikátor do URL i wiki ('advent-2026')
# data:: jsonb — definice otázek, správné odpovědi, nastavení
class Quiz < ActiveRecord::Base
  has_many :quiz_answers, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :quiz_type, inclusion: { in: %w[quiz advent poll] }, allow_nil: true

  ##
  # Je kvíz otevřený (lze odpovídat)?
  def open?(today = Date.today)
    (opens_on.nil? || opens_on <= today) && (closes_on.nil? || closes_on >= today)
  end

  ##
  # Advent: otázka (den) question_no se odemyká až opens_on + (question_no - 1).
  # Ostatní typy: stačí otevřený kvíz.
  def question_open?(question_no, today = Date.today)
    return false unless open?(today)
    return true unless quiz_type == 'advent'
    return false if opens_on.nil? || question_no.nil?
    opens_on + (question_no - 1) <= today
  end
end
```

```ruby
# app/models/quiz_answer.rb
##
# Odpověď přítele na otázku kvízu. Identita vždy přes friend_id
# (i pro přihlášené — viz navrh-kvizy-a-pratele.md).
class QuizAnswer < ActiveRecord::Base
  belongs_to :quiz
  belongs_to :friend

  validates :question_no, uniqueness: { scope: [:quiz_id, :friend_id] }
end
```

Do `app/models/user.rb` pod řádek `has_one :participant, ...` přidat:

```ruby
  has_one :friend, inverse_of: :user
```

- [ ] **Step 7: Spustit testy — musí projít**

Run: `RAILS_ENV=test bundle exec rails test test/unit/friend_test.rb test/unit/quiz_test.rb`
Expected: 0 failures. (První běh si přegeneruje testovací sqlite ze schema.rb.)

- [ ] **Step 8: Commit**

```bash
git add db/migrate/033_create_friends_and_quizzes.rb db/schema.rb config/initializers/sqlite3_timestamptz.rb app/models/friend.rb app/models/quiz.rb app/models/quiz_answer.rb app/models/user.rb test/unit/friend_test.rb test/unit/quiz_test.rb
git commit -m "kvizy: tabulky a modely friends, quizzes, quiz_answers"
```

---

### Task 2: Politika účtů — bez plošné role :user, bez timeoutu, dlouhé remember, confirm 7 dní

**Files:**
- Modify: `app/models/user.rb:43-47` (devise moduly), `:69-71` (before_create)
- Modify: `config/initializers/devise.rb:83` (confirm_within), `:90` (remember_for), `:96` (extend_remember_period), `:118` (timeout_in)
- Test: `test/unit/user_test.rb` (existující soubor — přidat testy)

**Interfaces:**
- Consumes: —
- Produces: `User.new(...).save` již NEPŘIDÁVÁ roli `:user`; solver/admin flow ji předává explicitně v `roles: [:user]` (už dnes, viz `sosna/solver_controller.rb:320`, `tep_controller.rb:87`).

- [ ] **Step 1: Failing testy** — do `test/unit/user_test.rb` přidat:

```ruby
  test "new user has no roles by default" do
    u = User.new(email: 'norole@x.cz', password: 'password123')
    u.skip_confirmation!
    u.save!
    assert_equal [], u.roles.to_a
    assert_not u.user?
  end

  test "explicit roles are kept" do
    u = User.new(email: 'srole@x.cz', password: 'password123', roles: [:user])
    u.skip_confirmation!
    u.save!
    assert u.user?
  end
```

- [ ] **Step 2: Spustit — první test failne** (`before_create` roli přidá)

Run: `RAILS_ENV=test bundle exec rails test test/unit/user_test.rb`

- [ ] **Step 3: Implementace**

V `app/models/user.rb`:
- smazat blok `before_create do roles << :user end` (řádky 69-71); místo něj komentář `# roli :user přiděluje explicitně registrace řešitele a admin (viz navrh-kvizy-a-pratele.md)`
- z devise modulů odebrat `:timeoutable,` a `:timeout_in => 60.minutes` (a čárku za `:validatable`).

V `config/initializers/devise.rb`:
- řádek 83: `config.confirm_within = 7.days`
- řádek 90: `config.remember_for = 1.year`
- řádek 96: `config.extend_remember_period = true` (odkomentovat a nastavit)
- řádek 118: zakomentovat `# config.timeout_in = 30.minutes` (timeoutable se už nepoužívá)

- [ ] **Step 4: Testy projdou + celá suite nezhoršena**

Run: `RAILS_ENV=test bundle exec rails test`
Expected: stále jen 4 baseline failures (tep_controller_test).

- [ ] **Step 5: Commit**

```bash
git add app/models/user.rb config/initializers/devise.rb test/unit/user_test.rb
git commit -m "ucty: role :user jen explicitne, zadny session timeout, remember 1 rok, confirm 7 dni"
```

---

### Task 3: FriendController — hello, status, claim/merge

**Files:**
- Create: `app/controllers/friend_controller.rb`
- Modify: `config/routes.rb` (za blok `# tep`, před `# post`), `app/models/ability.rb` (public sekce + org)
- Test: `test/functional/friend_controller_test.rb`

**Interfaces:**
- Consumes: `Friend` (Task 1)
- Produces: JSON API pro JS widget:
  - `POST /friend/hello` params `uuid` (volitelný), `nick` → `{uuid:, nick:, status:}` (založí/aktualizuje frienda, touchne `last_seen_at`)
  - `GET /friend/status` params `uuid` → nepřihlášen: `{uuid:, nick:, status:}` nebo `{status: 'unknown'}`; přihlášen: `{uuid:, nick:, status:, signed_in: true, merge_candidate: true/false}` (kanonický friend; auto-vytvoří se s nickem z `user.full_name`, pokud chybí a uživatel žádného nemá)
  - `POST /friend/claim` params `uuid` → přihlášený adoptuje anonymní friend uuid (nemá-li vlastního), nebo merge (odpovědi se přepojí, duplicitní zahodí, anonymní řádek smaže) → `{uuid:, nick:, status:}`

- [ ] **Step 1: Routes** — do `config/routes.rb` za řádek 171 (`user_finish_registration`):

```ruby
  # friend + quiz (kvízy, adventomat — viz navrh-kvizy-a-pratele.md)
  post '/friend/hello'          => 'friend#hello',         :as => :friend_hello
  get  '/friend/status'         => 'friend#status',        :as => :friend_status
  post '/friend/claim'          => 'friend#claim',         :as => :friend_claim
```

- [ ] **Step 2: Ability** — do public sekce `app/models/ability.rb` (za `can :access, :tep`):

```ruby
    # friend — kvízová identita (viz navrh-kvizy-a-pratele.md)
    can :hello,  :friend
    can :status, :friend
    can :claim,  :friend
```

- [ ] **Step 3: Failing testy**

```ruby
# test/functional/friend_controller_test.rb
require 'test_helper'

class FriendControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  def make_user(email)
    u = User.new(email: email, password: 'password123')
    u.skip_confirmation!
    u.save!
    u
  end

  test "hello creates friend and returns uuid" do
    post :hello, params: { nick: 'Petr' }
    json = JSON.parse(response.body)
    assert json['uuid'].present?
    assert_equal 'Petr', json['nick']
    assert_equal 'anonymous', json['status']
    assert Friend.find_by(uuid: json['uuid'])
  end

  test "hello with known uuid updates nick" do
    f = Friend.create!(nick: 'Petr')
    post :hello, params: { uuid: f.uuid, nick: 'PetrII' }
    assert_equal 'PetrII', f.reload.nick
    assert f.last_seen_at.present?
  end

  test "hello without nick fails" do
    post :hello, params: { nick: '' }
    assert_response :unprocessable_entity
  end

  test "status for unknown uuid" do
    get :status, params: { uuid: 'neexistuje' }
    assert_equal 'unknown', JSON.parse(response.body)['status']
  end

  test "status for anonymous friend" do
    f = Friend.create!(nick: 'Petr')
    get :status, params: { uuid: f.uuid }
    json = JSON.parse(response.body)
    assert_equal 'anonymous', json['status']
    assert_equal 'Petr', json['nick']
  end

  test "status signed in returns canonical friend and wins over localStorage" do
    u = make_user('a@x.cz')
    mine = Friend.create!(nick: 'Muj', user: u)
    other = Friend.create!(nick: 'Cizi')
    sign_in u
    get :status, params: { uuid: other.uuid }
    json = JSON.parse(response.body)
    assert_equal mine.uuid, json['uuid']
    assert json['signed_in']
    assert json['merge_candidate']
  end

  test "status signed in creates canonical friend when missing" do
    u = make_user('b@x.cz')
    sign_in u
    get :status
    json = JSON.parse(response.body)
    assert_equal 'verified', json['status']
    assert_equal u.reload.friend.uuid, json['uuid']
  end

  test "claim adopts anonymous friend when user has none" do
    u = make_user('c@x.cz')
    f = Friend.create!(nick: 'Anonym')
    sign_in u
    post :claim, params: { uuid: f.uuid }
    assert_equal u.id, f.reload.user_id
  end

  test "claim merges answers into canonical friend" do
    u = make_user('d@x.cz')
    mine = Friend.create!(nick: 'Muj', user: u)
    other = Friend.create!(nick: 'Cizi')
    q = Quiz.create!(name: 'k1')
    QuizAnswer.create!(quiz: q, friend: other, question_no: 1, answer: 'a')
    QuizAnswer.create!(quiz: q, friend: mine,  question_no: 2, answer: 'b')
    QuizAnswer.create!(quiz: q, friend: other, question_no: 2, answer: 'kolize')
    sign_in u
    post :claim, params: { uuid: other.uuid }
    assert_nil Friend.find_by(uuid: other.uuid)
    answers = QuizAnswer.where(friend_id: mine.id).order(:question_no)
    assert_equal [1, 2], answers.map(&:question_no)
    assert_equal 'b', answers.last.answer   # kanonická odpověď vyhrává
  end

  test "claim requires login" do
    f = Friend.create!(nick: 'Anonym')
    post :claim, params: { uuid: f.uuid }
    assert_response :redirect
  end
end
```

- [ ] **Step 4: Spustit — failnou** (`uninitialized constant FriendController`)

Run: `RAILS_ENV=test bundle exec rails test test/functional/friend_controller_test.rb`

- [ ] **Step 5: Implementace controlleru**

```ruby
# app/controllers/friend_controller.rb
##
# Přítel Pikomatu — kvízová identita a její napojení na účet
# (viz navrh-kvizy-a-pratele.md).
#
# JSON API pro hlavičkový widget a kvízový JS. Anonymní identita se
# prokazuje uuid (drží ho prohlížeč v localStorage); přihlášený uživatel
# má vždy přednost — dostává svého kanonického frienda.
class FriendController < ApplicationController
  authorize_resource :class => false

  ##
  # POST /friend/hello — založ/aktualizuj anonymního frienda
  # *Params* uuid (volitelný), nick
  def hello
    friend = params[:uuid].present? ? Friend.find_by(uuid: params[:uuid]) : nil
    friend ||= Friend.new
    friend.nick = params[:nick] if params[:nick].present? || friend.new_record?
    friend.last_seen_at = Time.now
    if friend.save
      render json: friend_json(friend)
    else
      render json: { errors: friend.errors.full_messages }, status: :unprocessable_entity
    end
  end

  ##
  # GET /friend/status — stav pro widget
  # *Params* uuid (ignoruje se, je-li přihlášen)
  def status
    if current_user
      friend = canonical_friend(current_user)
      merge_candidate = params[:uuid].present? && params[:uuid] != friend.uuid &&
                        Friend.where(uuid: params[:uuid], user_id: nil).exists?
      render json: friend_json(friend).merge(signed_in: true, merge_candidate: merge_candidate)
    else
      friend = Friend.find_by(uuid: params[:uuid].to_s)
      if friend
        friend.update_column(:last_seen_at, Time.now)
        render json: friend_json(friend)
      else
        render json: { status: 'unknown' }
      end
    end
  end

  ##
  # POST /friend/claim — přihlášený si přivlastní anonymního frienda
  # (adopce, nebo merge odpovědí do kanonického)
  # *Params* uuid
  def claim
    return redirect_to new_user_session_path unless current_user
    other = Friend.find_by(uuid: params[:uuid].to_s, user_id: nil)
    mine = current_user.friend
    if other.nil?
      friend = canonical_friend(current_user)
    elsif mine.nil?
      other.update!(user: current_user)
      friend = other
    else
      merge_friends(mine, other)
      friend = mine
    end
    render json: friend_json(friend)
  end

  private

  ##
  # Kanonický friend přihlášeného; založí ho, pokud chybí.
  def canonical_friend(user)
    user.friend || Friend.create!(user: user, nick: user.full_name)
  end

  ##
  # Přepoj odpovědi z other na mine (kolize vyhrává mine) a other smaž.
  def merge_friends(mine, other)
    Friend.transaction do
      other.quiz_answers.each do |ans|
        next if QuizAnswer.where(quiz_id: ans.quiz_id, question_no: ans.question_no,
                                 friend_id: mine.id).exists?
        ans.update_columns(friend_id: mine.id)
      end
      other.reload.destroy
    end
  end

  def friend_json(friend)
    { uuid: friend.uuid, nick: friend.nick, status: friend.status }
  end
end
```

- [ ] **Step 6: Testy projdou**

Run: `RAILS_ENV=test bundle exec rails test test/functional/friend_controller_test.rb`
Expected: 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/friend_controller.rb config/routes.rb app/models/ability.rb test/functional/friend_controller_test.rb
git commit -m "friend: api hello/status/claim, merge odpovedi pri prihlaseni"
```

---

### Task 4: Registrace přítele — email, ověřovací link (7 dní), dokončení s heslem, resend

**Files:**
- Modify: `app/controllers/friend_controller.rb` (akce `register_form`, `register`, `finish`, `do_finish`, `resend`)
- Modify: `config/routes.rb`, `app/models/ability.rb`
- Create: `app/views/friend/register_form.html.erb`, `app/views/friend/finish.html.erb`
- Create: `app/views/tep/mailer/confirmation_instructions.html.erb`
- Test: `test/functional/friend_controller_test.rb` (rozšířit)

**Interfaces:**
- Consumes: `Friend`, Devise confirmable (`user.send_confirmation_instructions`, `confirmation_token`, `user.confirm`), `Tep::Mailer`
- Produces:
  - `GET /pritel` → formulář (email + nick)
  - `POST /friend/register` params `uuid`, `email`, `nick` → založí neověřeného Usera (bez role, náhodné heslo), propojí frienda, pošle confirmation mail; existuje-li email, pošle reset-password instrukce (anti-enumeration: web odpoví vždy stejně)
  - `GET /friend/finish/:token` → formulář hesla; `POST /friend/finish/:token` params `password`, `password_confirmation` → nastaví heslo, `confirm`, přihlásí
  - `POST /friend/resend` params `uuid` → znovu pošle confirmation

- [ ] **Step 1: Routes** — pod routy z Task 3:

```ruby
  get  '/pritel'                => 'friend#register_form', :as => :friend_register_form
  post '/friend/register'       => 'friend#register',      :as => :friend_register
  post '/friend/resend'         => 'friend#resend',        :as => :friend_resend
  get  '/friend/finish/:token'  => 'friend#finish',        :as => :friend_finish
  post '/friend/finish/:token'  => 'friend#do_finish',     :as => :friend_do_finish
```

- [ ] **Step 2: Ability** — do public sekce:

```ruby
    can :register_form, :friend
    can :register,      :friend
    can :resend,        :friend
    can :finish,        :friend
    can :do_finish,     :friend
```

- [ ] **Step 3: Failing testy** — přidat do `test/functional/friend_controller_test.rb`:

```ruby
  test "register creates unverified user without roles and sends mail" do
    f = Friend.create!(nick: 'Petr')
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      post :register, params: { uuid: f.uuid, email: 'novy@x.cz' }
    end
    u = User.find_by(email: 'novy@x.cz')
    assert u
    assert_nil u.confirmed_at
    assert_equal [], u.roles.to_a
    assert_equal u.id, f.reload.user_id
    assert_equal 'unverified', f.status
  end

  test "register with taken email does not create user, responds identically" do
    make_user('mam@x.cz')
    f = Friend.create!(nick: 'Petr')
    assert_no_difference 'User.count' do
      post :register, params: { uuid: f.uuid, email: 'mam@x.cz' }
    end
    assert_response :redirect  # stejná odpověď jako úspěch
    assert_nil f.reload.user_id
  end

  test "register with invalid email shows error" do
    f = Friend.create!(nick: 'Petr')
    post :register, params: { uuid: f.uuid, email: 'blbost' }
    assert flash[:alert].present?
  end

  test "finish sets password confirms and signs in" do
    f = Friend.create!(nick: 'Petr')
    post :register, params: { uuid: f.uuid, email: 'fin@x.cz' }
    u = User.find_by(email: 'fin@x.cz')
    token = u.confirmation_token
    get :finish, params: { token: token }
    assert_response :success
    post :do_finish, params: { token: token, password: 'tajneheslo1', password_confirmation: 'tajneheslo1' }
    u.reload
    assert u.confirmed_at.present?
    assert u.valid_password?('tajneheslo1')
    assert_equal 'verified', f.reload.status
  end

  test "finish with bad token fails" do
    get :finish, params: { token: 'spatny' }
    assert_response :redirect
    assert flash[:alert].present?
  end

  test "resend sends confirmation again" do
    f = Friend.create!(nick: 'Petr')
    post :register, params: { uuid: f.uuid, email: 're@x.cz' }
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      post :resend, params: { uuid: f.uuid }
    end
  end
```

- [ ] **Step 4: Spustit — failnou** (missing actions)

Run: `RAILS_ENV=test bundle exec rails test test/functional/friend_controller_test.rb`

- [ ] **Step 5: Implementace akcí** — do `FriendController`:

```ruby
  ##
  # GET /pritel — registrační formulář přítele Pikomatu
  def register_form
    @nick = params[:nick]
  end

  ##
  # POST /friend/register — zaregistruj přítele (jen email)
  # Neprozrazuje, zda email existuje (anti-enumeration): odpověď je
  # vždy stejná, jen se pošle jiný mail.
  def register
    friend = Friend.find_by(uuid: params[:uuid].to_s)
    email = params[:email].to_s.downcase.strip
    unless email =~ Devise.email_regexp
      add_alert 'Zadej platnou emailovou adresu.'
      return redirect_to friend_register_form_path
    end
    if friend.nil?
      friend = Friend.new(nick: params[:nick])
      unless friend.save
        add_alert 'Zadej přezdívku.'
        return redirect_to friend_register_form_path
      end
    end

    existing = User.find_by_email(email)
    if existing
      # účet už je — pošli návod na přihlášení/reset, web mlčí
      existing.send_reset_password_instructions
    else
      user = User.new(email: email, password: SecureRandom.hex(16))
      user.save!
      friend.update!(user: user) if friend.user_id.nil?
      user.send_confirmation_instructions
    end
    add_notice 'Koukni do mailu a dokonči registraci (link platí 7 dní).'
    redirect_to root_path
  end

  ##
  # GET /friend/finish/:token — dokončení: potvrzení mailu + heslo
  def finish
    @user = User.find_by(confirmation_token: params[:token])
    if @user.nil? || @user.confirmed_at
      add_alert 'Odkaz je neplatný nebo už použitý.'
      return redirect_to root_path
    end
    @token = params[:token]
  end

  ##
  # POST /friend/finish/:token — nastav heslo, potvrď, přihlas
  def do_finish
    user = User.find_by(confirmation_token: params[:token])
    if user.nil? || user.confirmed_at
      add_alert 'Odkaz je neplatný nebo už použitý.'
      return redirect_to root_path
    end
    user.password = params[:password]
    user.password_confirmation = params[:password_confirmation]
    if user.save
      user.confirm
      sign_in(user)
      add_notice 'Registrace dokončena, vítej!'
      redirect_to root_path
    else
      add_alert user.errors.full_messages.join(', ')
      redirect_to friend_finish_path(token: params[:token])
    end
  end

  ##
  # POST /friend/resend — znovu pošli dokončovací link
  def resend
    friend = Friend.find_by(uuid: params[:uuid].to_s)
    user = friend && friend.user
    if user && user.confirmed_at.nil?
      user.send_confirmation_instructions
      add_notice 'Dokončovací mail poslán znovu.'
    end
    redirect_to root_path
  end
```

Pozn.: `add_alert`/`add_notice` — ověř, že existují v `ApplicationController` (používá je `sosna/solver_controller.rb`); pokud je tam jen `add_alert`, pro notice použij `flash[:success]` podle stylu `tep_controller.rb`.

- [ ] **Step 6: Views**

```erb
<%# app/views/friend/register_form.html.erb %>
<div class="page-header"><h1>Přítel Pikomatu</h1></div>
<p>Stačí email — pošleme ti odkaz, kterým registraci dokončíš (platí 7 dní).</p>
<%= form_tag friend_register_path, method: :post do %>
  <input type="hidden" name="uuid" id="friend-form-uuid">
  <div class="form-group">
    <label>Přezdívka</label>
    <input type="text" name="nick" id="friend-form-nick" class="form-control" value="<%= @nick %>">
  </div>
  <div class="form-group">
    <label>Email</label>
    <input type="email" name="email" class="form-control" required>
  </div>
  <button type="submit" class="btn btn-primary">Zaregistrovat</button>
<% end %>
<script>
  // předvyplň z localStorage
  (function() {
    var f = {};
    try { f = JSON.parse(localStorage.getItem('friend')) || {}; } catch (e) {}
    if (f.uuid) document.getElementById('friend-form-uuid').value = f.uuid;
    var nickEl = document.getElementById('friend-form-nick');
    if (f.nick && !nickEl.value) nickEl.value = f.nick;
  })();
</script>
```

```erb
<%# app/views/friend/finish.html.erb %>
<div class="page-header"><h1>Dokončení registrace</h1></div>
<p>Účet <b><%= @user.email %></b> — zbývá nastavit heslo.</p>
<%= form_tag friend_do_finish_path(token: @token), method: :post do %>
  <div class="form-group">
    <label>Heslo</label>
    <input type="password" name="password" class="form-control" required>
  </div>
  <div class="form-group">
    <label>Heslo znovu</label>
    <input type="password" name="password_confirmation" class="form-control" required>
  </div>
  <button type="submit" class="btn btn-primary">Dokončit registraci</button>
<% end %>
```

```erb
<%# app/views/tep/mailer/confirmation_instructions.html.erb %>
<p>Ahoj<%= @resource.friend ? " #{@resource.friend.nick}" : '' %>,</p>
<p>vítej mezi přáteli Pikomatu! Registraci dokončíš (a heslo si nastavíš) tímto odkazem:</p>
<p><%= link_to 'Dokončit registraci', friend_finish_url(token: @token) %></p>
<p>Odkaz platí 7 dní. Pokud sis registraci nevyžádal(a), tento mail ignoruj.</p>
<p>Pikomat</p>
```

- [ ] **Step 7: Testy projdou**

Run: `RAILS_ENV=test bundle exec rails test test/functional/friend_controller_test.rb`
Expected: 0 failures.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/friend_controller.rb app/views/friend app/views/tep/mailer/confirmation_instructions.html.erb config/routes.rb app/models/ability.rb test/functional/friend_controller_test.rb
git commit -m "friend: registrace pritele pikomatu, overeni mailem s nastavenim hesla, resend"
```

---

### Task 5: QuizController — odpovědi a výsledkovka

**Files:**
- Create: `app/controllers/quiz_controller.rb`, `app/views/quiz/vysledky.html.erb`
- Modify: `config/routes.rb`, `app/models/ability.rb`
- Test: `test/functional/quiz_controller_test.rb`

**Interfaces:**
- Consumes: `Quiz#question_open?`, `Friend`, `QuizAnswer`, `FriendController`-style uuid identita
- Produces:
  - `POST /quiz/:name/answer` params `uuid`, `nick`, `question_no`, `answer`, `data` (volitelný), `website` (honeypot — musí být prázdný) → `{ok: true, uuid:, correct: true/false/null}`; friend vzniká lazy; přihlášený jde přes kanonického frienda; upsert (opakovaná odpověď přepíše starou)
  - `GET /quiz/:name/vysledky` → HTML výsledkovka (počet odpovědí na frienda, nick + diskriminátor + odznak ověření)

- [ ] **Step 1: Routes**

```ruby
  post '/quiz/:name/answer'     => 'quiz#answer',          :as => :quiz_answer
  get  '/quiz/:name/vysledky'   => 'quiz#vysledky',        :as => :quiz_vysledky
```

- [ ] **Step 2: Ability** — public sekce:

```ruby
    can :answer,   Quiz
    can :vysledky, Quiz
```

- [ ] **Step 3: Failing testy**

```ruby
# test/functional/quiz_controller_test.rb
require 'test_helper'

class QuizControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @quiz = Quiz.create!(name: 'kviz-pi', quiz_type: 'quiz',
                         data: { 'correct' => { '1' => '42' } })
  end

  test "answer creates friend lazily and stores answer" do
    post :answer, params: { name: 'kviz-pi', nick: 'Petr', question_no: 1, answer: '42' }
    json = JSON.parse(response.body)
    assert json['ok']
    f = Friend.find_by(uuid: json['uuid'])
    assert_equal 'Petr', f.nick
    assert_equal '42', QuizAnswer.find_by(quiz: @quiz, friend: f, question_no: 1).answer
  end

  test "answer upserts on repeat" do
    f = Friend.create!(nick: 'Petr')
    post :answer, params: { name: 'kviz-pi', uuid: f.uuid, question_no: 1, answer: 'a' }
    post :answer, params: { name: 'kviz-pi', uuid: f.uuid, question_no: 1, answer: 'b' }
    assert_equal 1, QuizAnswer.where(quiz: @quiz, friend: f).count
    assert_equal 'b', QuizAnswer.find_by(quiz: @quiz, friend: f).answer
  end

  test "closed quiz rejects answers" do
    @quiz.update!(closes_on: Date.yesterday)
    post :answer, params: { name: 'kviz-pi', nick: 'Petr', question_no: 1, answer: 'x' }
    assert_response :forbidden
  end

  test "advent locked day rejects answers" do
    Quiz.create!(name: 'advent', quiz_type: 'advent',
                 opens_on: Date.today, closes_on: Date.today + 30)
    post :answer, params: { name: 'advent', nick: 'P', question_no: 5, answer: 'x' }
    assert_response :forbidden
  end

  test "honeypot silently drops" do
    post :answer, params: { name: 'kviz-pi', nick: 'Bot', question_no: 1, answer: 'x', website: 'spam' }
    assert_equal 0, QuizAnswer.count
    assert JSON.parse(response.body)['ok']   # bot nepozná, že neuspěl
  end

  test "signed in user answers via canonical friend" do
    u = User.new(email: 'q@x.cz', password: 'password123')
    u.skip_confirmation!
    u.save!
    sign_in u
    post :answer, params: { name: 'kviz-pi', question_no: 1, answer: '42' }
    assert_equal u.reload.friend.id, QuizAnswer.last.friend_id
  end

  test "vysledky renders scoreboard" do
    f1 = Friend.create!(nick: 'Petr')
    f2 = Friend.create!(nick: 'Petr')
    QuizAnswer.create!(quiz: @quiz, friend: f1, question_no: 1, answer: '42')
    QuizAnswer.create!(quiz: @quiz, friend: f2, question_no: 1, answer: 'ne')
    get :vysledky, params: { name: 'kviz-pi' }
    assert_response :success
    assert_match 'Petr', response.body
    assert_match f1.discriminator, response.body
  end

  test "unknown quiz 404" do
    post :answer, params: { name: 'neni', question_no: 1, answer: 'x' }
    assert_response :not_found
  end
end
```

- [ ] **Step 4: Spustit — failnou**

Run: `RAILS_ENV=test bundle exec rails test test/functional/quiz_controller_test.rb`

- [ ] **Step 5: Implementace**

```ruby
# app/controllers/quiz_controller.rb
##
# Kvízy a adventomat — příjem odpovědí a výsledkovka
# (viz navrh-kvizy-a-pratele.md).
class QuizController < ApplicationController
  authorize_resource :class => false

  THROTTLE_PER_MINUTE = 30

  ##
  # POST /quiz/:name/answer
  # *Params*
  # name:: identifikátor kvízu (quizzes.name)
  # uuid:: friend uuid (nepovinné, založí se lazy z nick)
  # nick:: přezdívka pro lazy založení
  # question_no:: číslo otázky (advent: den)
  # answer:: odpověď
  # website:: honeypot — vyplněné pole = bot, tiše zahodit
  def answer
    quiz = Quiz.find_by(name: params[:name])
    return head :not_found unless quiz
    return render json: { ok: true } if params[:website].present?  # honeypot

    question_no = params[:question_no].to_i
    unless quiz.question_open?(question_no)
      return render json: { ok: false, error: 'Kvíz (nebo tento den) není otevřený.' }, status: :forbidden
    end

    friend = find_or_create_friend
    return render json: { ok: false, error: 'Chybí přezdívka.' }, status: :unprocessable_entity unless friend

    if QuizAnswer.where(friend_id: friend.id).where('created_at > ?', 1.minute.ago).count >= THROTTLE_PER_MINUTE
      return render json: { ok: false, error: 'Zpomal trochu.' }, status: :too_many_requests
    end

    ans = QuizAnswer.find_or_initialize_by(quiz: quiz, friend: friend, question_no: question_no)
    ans.answer = params[:answer].to_s
    ans.data = params[:data] if params[:data].present?
    ans.save!
    render json: { ok: true, uuid: friend.uuid, correct: correct?(quiz, question_no, ans.answer) }
  end

  ##
  # GET /quiz/:name/vysledky — pseudo-výsledkovka
  # *Provides* @quiz, @rows (friend + počet odpovědí, u kvízu se
  # správnými odpověďmi počet správných)
  def vysledky
    @quiz = Quiz.find_by(name: params[:name])
    return head :not_found unless @quiz
    answers = @quiz.quiz_answers.includes(friend: :user)
    @rows = answers.group_by(&:friend).map do |friend, list|
      correct = list.count { |a| correct?(@quiz, a.question_no, a.answer) == true }
      { friend: friend, count: list.size, correct: correct,
        last: list.map(&:updated_at).max }
    end.sort_by { |r| [-r[:correct], -r[:count]] }
  end

  private

  ##
  # Přihlášený → kanonický friend; jinak dle uuid; jinak lazy z nick.
  def find_or_create_friend
    if current_user
      return current_user.friend || Friend.create!(user: current_user, nick: current_user.full_name)
    end
    friend = Friend.find_by(uuid: params[:uuid].to_s) if params[:uuid].present?
    return friend if friend
    return nil if params[:nick].to_s.strip.empty?
    Friend.create(nick: params[:nick]).persisted? ? Friend.find_by(nick: params[:nick].to_s.strip) : nil
  end

  ##
  # true/false podle quiz.data['correct'][question_no], nil když kvíz
  # správné odpovědi nedefinuje (poll)
  def correct?(quiz, question_no, answer)
    correct = quiz.data && quiz.data['correct']
    return nil unless correct
    expected = correct[question_no.to_s]
    return nil if expected.nil?
    expected.to_s.strip.casecmp?(answer.to_s.strip)
  end
end
```

Pozor v `find_or_create_friend`: poslední řádek je křehký (dva stejné nicky). Správně:

```ruby
    f = Friend.new(nick: params[:nick])
    f.save ? f : nil
```

- [ ] **Step 6: View výsledkovky**

```erb
<%# app/views/quiz/vysledky.html.erb %>
<div class="page-header"><h1><%= @quiz.title || @quiz.name %> — výsledky</h1></div>
<table class="table table-striped table-bordered">
  <thead><tr><th>#</th><th>Přezdívka</th><th>Vyřešeno</th></tr></thead>
  <tbody>
    <% @rows.each_with_index do |row, i| %>
      <tr>
        <td><%= i + 1 %></td>
        <td>
          <%= row[:friend].display_nick %>
          <small class="grey">·<%= row[:friend].discriminator %></small>
          <% case row[:friend].status %>
          <% when 'verified' %><i class="ace-icon fa fa-check green" title="ověřený přítel Pikomatu"></i>
          <% when 'unverified' %><small class="orange">(neověřen)</small>
          <% end %>
        </td>
        <td><%= @quiz.data && @quiz.data['correct'] ? row[:correct] : row[:count] %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

- [ ] **Step 7: Testy projdou**

Run: `RAILS_ENV=test bundle exec rails test test/functional/quiz_controller_test.rb`
Expected: 0 failures.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/quiz_controller.rb app/views/quiz config/routes.rb app/models/ability.rb test/functional/quiz_controller_test.rb
git commit -m "quiz: prijem odpovedi (honeypot, throttle, advent dny) a vysledkovka"
```

---

### Task 6: Hlavičkový widget (4 stavy) + JS identita + adventomat POST

**Files:**
- Modify: `app/views/layouts/application.html.erb:99-101` (else větev přihlášení)
- Modify: `public/javascripts/tep.js` (nové funkce + úprava `init_adventomat`)

**Interfaces:**
- Consumes: `GET /friend/status`, `POST /friend/claim`, `POST /quiz/:name/answer` (Tasky 3-5); localStorage klíč `friend` = JSON `{"uuid":..., "nick":...}`
- Produces: widget `#friend-widget` (stavy: skrytý / nick+vykřičník / nick+trojúhelníček+resend); adventomat POSTuje vyřešené dny, když má modal `data-quiz`.

Netestovatelné minitestem (JS) — ověřuje se ručně, viz Step 4.

- [ ] **Step 1: Layout** — v `app/views/layouts/application.html.erb` nahradit řádky 99-101:

```erb
          <% else %>
            <li id="friend-widget" class="hide">
              <a href="#" class="dropdown-toggle btn tep-transparent" data-toggle="dropdown">
                <i class="ace-icon fa fa-user"></i>
                <span id="friend-widget-nick"></span>
                <span id="friend-widget-bang" class="badge badge-warning hide">!</span>
                <i id="friend-widget-warn" class="ace-icon fa fa-warning orange hide"></i>
              </a>
              <ul class="dropdown-menu dropdown-menu-right">
                <li class="friend-anonymous"><a href="/pritel">Zaregistruj se jako přítel Pikomatu (stačí email)</a></li>
                <li class="friend-anonymous"><a href="/prihlaska">Staň se řešitelem Pikomatu</a></li>
                <li class="friend-anonymous"><%= link_to 'Přihlásit se', :new_user_session %></li>
                <li class="friend-unverified hide"><a href="#" id="friend-widget-resend">Dokonči registraci — poslat mail znovu</a></li>
              </ul>
            </li>
            <li id="friend-login-link"><%= ilink_to 'Přihlášení', :new_user_session , :ico => 'fa-user', :class=> 'btn tep-transparent' %> </li>
          <% end %>
```

A do přihlášené větve (za řádek 97 s `label-user`) přidat marker pro JS:

```erb
            <script>window.tep_signed_in = true;</script>
```

- [ ] **Step 2: tep.js — identita a widget** — přidat na konec souboru:

```javascript
/* ---- friend: kvízová identita (viz navrh-kvizy-a-pratele.md) ---- */

function friend_get() {
    try { return JSON.parse(localStorage.getItem('friend')) || {} }
    catch (e) { return {} }
}

function friend_set(f) {
    localStorage.setItem('friend', JSON.stringify({uuid: f.uuid, nick: f.nick}))
}

function friend_csrf() {
    return $('meta[name="csrf-token"]').attr('content')
}

/* Zavolej /friend/status a nastav widget. Přihlášený vyhrává:
   server vrátí kanonického frienda, localStorage se přepíše. */
function init_friend_widget() {
    var f = friend_get()
    if (window.tep_signed_in) {
        $.get('/friend/status', {uuid: f.uuid || ''}, function (json) {
            if (json.merge_candidate &&
                confirm('Na tomto zařízení jsou kvízové odpovědi pod přezdívkou z dřívějška. Připojit k tvému účtu?')) {
                $.post('/friend/claim', {uuid: f.uuid, authenticity_token: friend_csrf()},
                       function (j2) { friend_set(j2) })
            } else {
                friend_set(json)
            }
        })
        return
    }
    if (!f.uuid && !f.nick) return   // stav 1: nic — zůstává jen Přihlášení
    $.get('/friend/status', {uuid: f.uuid || ''}, function (json) {
        if (json.status === 'unknown') return
        friend_set(json)
        $('#friend-widget-nick').text(json.nick)
        $('#friend-widget').removeClass('hide')
        $('#friend-login-link').addClass('hide')
        if (json.status === 'unverified') {          // stav 3: trojúhelníček + resend
            $('#friend-widget-warn').removeClass('hide')
            $('.friend-anonymous').addClass('hide')
            $('.friend-unverified').removeClass('hide')
        } else {                                     // stav 2: vykřičník
            $('#friend-widget-bang').removeClass('hide')
        }
    })
}

/* Zajisti frienda (lazy) a předej ho callbacku. Ptá se na nick, když chybí. */
function friend_ensure(cb) {
    var f = friend_get()
    if (f.uuid) return cb(f)
    if (window.tep_signed_in) {
        $.get('/friend/status', function (json) { friend_set(json); cb(json) })
        return
    }
    var nick = f.nick || prompt('Zadej přezdívku do výsledkovky (nepovinné):')
    if (!nick) return cb(null)
    $.post('/friend/hello', {nick: nick, authenticity_token: friend_csrf()}, function (json) {
        friend_set(json)
        cb(json)
    })
}
```

Do `$(function() {...})` hlavního bloku (vedle `init_adventomat`, řádek ~235) přidat:

```javascript
      init_friend_widget()
      $('#friend-widget-resend').click(function (ev) {
          ev.preventDefault()
          $.post('/friend/resend', {uuid: friend_get().uuid, authenticity_token: friend_csrf()},
                 function () { alert('Mail poslán znovu. Koukni do schránky.') })
      })
```

- [ ] **Step 3: adventomat POST** — v `init_adventomat` za `adventomat_set_button_solved(date)` (řádek ~289) přidat:

```javascript
              var quiz_name = $('#adventomat-modal').data('quiz')
              if (quiz_name) {
                  friend_ensure(function (f) {
                      if (!f) return   // bez přezdívky jen localStorage jako dřív
                      $.post('/quiz/' + quiz_name + '/answer',
                             {uuid: f.uuid, question_no: parseInt(date, 10),
                              answer: her_solution, authenticity_token: friend_csrf()})
                  })
              }
```

(Wiki stránka adventomatu dostane na modal `data-quiz="advent-2026"`; bez atributu se chová jako dnes.)

- [ ] **Step 4: Ruční ověření**

1. `RAILS_ENV=local bundle exec rails server` (local prostředí, sqlite).
2. Anonymně: konzole `localStorage.setItem('friend', JSON.stringify({nick:'Test'}))`… lépe: na stránce kvízu odpovědět → prompt na nick → widget po reloadu ukazuje nick + `!`.
3. `/pritel` → registrace emailem → mail v logu (`log/local.log`), link `/friend/finish/<token>` → heslo → přihlášen, widget zmizel, nahoře email.
4. Widget pro neověřeného: po registraci (před klikem na link) reload → nick + oranžový trojúhelníček, v menu resend.
5. Kontrola `layouts/application.html.erb` syntaxe: `ruby -e "require 'erb'; ERB.new(File.read('app/views/layouts/application.html.erb'), trim_mode: '-').src" >/dev/null`

- [ ] **Step 5: Commit**

```bash
git add app/views/layouts/application.html.erb public/javascripts/tep.js
git commit -m "friend: hlavickovy widget (4 stavy), js identita, adventomat posila odpovedi"
```

---

### Task 7: Převzetí neověřeného účtu řešitelskou registrací + admin filtr „bez role"

**Files:**
- Modify: `app/controllers/sosna/solver_controller.rb:327-330` (else větev existujícího usera)
- Modify: `app/controllers/tep_controller.rb:46-55` (`users`)
- Modify: `app/views/tep/users.html.erb` (odkaz na filtr — najít místo, kde se vypisují role filtry, přidat „bez role")
- Test: `test/functional/sosna_solver_controller_test.rb` (nový), `test/functional/tep_controller_test.rb` (rozšířit)

**Interfaces:**
- Consumes: `User#send_first_login_instructions`, `Friend`
- Produces: registrace řešitele s emailem neověřeného přítele účet potvrdí, přidá `:user` a pošle first-login; `GET /users/none` vylistuje uživatele bez rolí.

- [ ] **Step 1: Failing testy**

```ruby
# test/functional/sosna_solver_controller_test.rb
require 'test_helper'

class SosnaSolverControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers
  tests Sosna::SolverController

  test "solver registration takes over unverified friend account" do
    friend_user = User.new(email: 'kid@x.cz', password: SecureRandom.hex(16))
    friend_user.save!   # neověřený, bez role (jako po friend#register)
    Friend.create!(nick: 'Kid', user: friend_user)
    Sosna::Config.create!(config_key: 'annual', value: '33') rescue nil

    post :create, params: {
      sosna_solver: { name: 'Jan', last_name: 'Novak', email: 'kid@x.cz',
                      birth: '1. 1. 2013', grade: 'sedmá třída', grade_num: '7',
                      where_to_send: 'home', street: 'X', num: '1', city: 'Praha',
                      psc: '10000', state: 'cz' },
      souhlasim: '1',
      school: { universal_id: 'nova', name: 'ZS Test', street: 'S', num: '2',
                city: 'Praha', psc: '10000', state: 'cz' }
    }
    friend_user.reload
    assert friend_user.confirmed_at.present?, 'převzatý účet má být potvrzen'
    assert friend_user.user?, 'převzatý účet má dostat roli :user'
  end
end
```

Pozn.: přesné parametry formuláře ověř podle `Sosna::Solver` validací a `load_config`
(`app/controllers/sosna/solver_controller.rb` + `app/models/sosna/solver.rb`) — test
musí projít validacemi (věk < 17 let, PSČ, škola). Pokud `load_config` čte
`Sosna::Config` jinak, uprav setup podle `sosna_configs` (key/value).

Do `test/functional/tep_controller_test.rb` přidat:

```ruby
  test "users filter none lists roleless users" do
    norole = User.new(email: 'norole@x.cz', password: 'password123')
    norole.skip_confirmation!
    norole.save!
    get :users, params: { role: 'none' }
    assert_includes assigns(:users), norole
    assert_not_includes assigns(:users), @admin
  end
```

- [ ] **Step 2: Spustit — failnou**

Run: `RAILS_ENV=test bundle exec rails test test/functional/sosna_solver_controller_test.rb test/functional/tep_controller_test.rb`

- [ ] **Step 3: Implementace**

`app/controllers/sosna/solver_controller.rb` — nahradit else větev (řádky 327-330):

```ruby
    else
      solver.user_id = user.id
      # přítel Pikomatu (i neověřený) se stává řešitelem — viz navrh-kvizy-a-pratele.md
      user.roles << :user unless user.user?
      if user.confirmed_at.nil?
        user.confirm
        user.send_first_login_instructions(is_bonus) if send_first
      else
        send_first = false
      end
      user.save
    end
```

`app/controllers/tep_controller.rb` — upravit `users`:

```ruby
  def users
    @role = params[:role]
    if @role == 'none'
      # přátelé Pikomatu bez role — viz navrh-kvizy-a-pratele.md
      @users = User.where('roles_mask IS NULL OR roles_mask = 0')
    elsif @role
       mask = User.mask_for @role.to_sym
       @users = User.where('roles_mask & ? > 0', mask)
    else
      @users = User.all.load
    end
  end
```

V `app/views/tep/users.html.erb` najít výpis odkazů na role filtry (hledej `users_list`) a přidat vedle nich odkaz `<%= link_to 'bez role', users_list_path(role: 'none') %>` ve stejném stylu.

- [ ] **Step 4: Testy projdou, suite nezhoršena**

Run: `RAILS_ENV=test bundle exec rails test`
Expected: max 4 baseline failures.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/sosna/solver_controller.rb app/controllers/tep_controller.rb app/views/tep/users.html.erb test/functional/sosna_solver_controller_test.rb test/functional/tep_controller_test.rb
git commit -m "solver: prevezme neovereny ucet pritele; admin filtr uzivatelu bez role"
```

---

### Task 8: Retence — rake task na úklid

**Files:**
- Create: `lib/tasks/friends_cleanup.rake`
- Test: `test/unit/friends_cleanup_test.rb`

**Interfaces:**
- Consumes: `Friend`, `User`, `Sosna::Solver`
- Produces: `rake friends:cleanup` — smaže anonymní friendy neaktivní > 1 rok (s odpověďmi) a neověřené users > 1 měsíc bez vazeb (friend se odpojí, ne smaže).

- [ ] **Step 1: Failing test**

```ruby
# test/unit/friends_cleanup_test.rb
require 'test_helper'
require 'rake'

class FriendsCleanupTest < ActiveSupport::TestCase
  setup do
    Tep::Application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task['friends:cleanup'].reenable
  end

  test "deletes stale anonymous friends with answers" do
    stale = Friend.create!(nick: 'Stary', last_seen_at: 2.years.ago)
    fresh = Friend.create!(nick: 'Novy', last_seen_at: 1.day.ago)
    q = Quiz.create!(name: 'q')
    QuizAnswer.create!(quiz: q, friend: stale, question_no: 1, answer: 'x')
    Rake::Task['friends:cleanup'].invoke
    assert_nil Friend.find_by(id: stale.id)
    assert Friend.find_by(id: fresh.id)
    assert_equal 0, QuizAnswer.where(friend_id: stale.id).count
  end

  test "deletes old unconfirmed users and unlinks friend" do
    u = User.new(email: 'stale@x.cz', password: SecureRandom.hex(16),
                 confirmation_sent_at: 2.months.ago)
    u.save!
    u.update_column(:confirmation_sent_at, 2.months.ago)
    f = Friend.create!(nick: 'P', user: u, last_seen_at: 1.day.ago)
    Rake::Task['friends:cleanup'].invoke
    assert_nil User.find_by(id: u.id)
    assert_nil f.reload.user_id, 'friend se vrací do anonymního stavu'
  end

  test "keeps unconfirmed user with solver" do
    u = User.new(email: 'sol@x.cz', password: SecureRandom.hex(16))
    u.save!
    u.update_column(:confirmation_sent_at, 2.months.ago)
    Sosna::Solver.create!(name: 'J', last_name: 'N', annual: '33',
                          email: 'sol@x.cz', user_id: u.id, where_to_send: 'home')
    Rake::Task['friends:cleanup'].invoke
    assert User.find_by(id: u.id)
  end
end
```

- [ ] **Step 2: Spustit — failne** (`Don't know how to build task 'friends:cleanup'`)

Run: `RAILS_ENV=test bundle exec rails test test/unit/friends_cleanup_test.rb`

- [ ] **Step 3: Implementace**

```ruby
# lib/tasks/friends_cleanup.rake
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
```

- [ ] **Step 4: Testy projdou**

Run: `RAILS_ENV=test bundle exec rails test test/unit/friends_cleanup_test.rb`
Expected: 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/tasks/friends_cleanup.rake test/unit/friends_cleanup_test.rb
git commit -m "friends: rake task na retenci (anonymni >1 rok, neoverene ucty >1 mesic)"
```

---

### Task 9: Závěrečná kontrola

- [ ] **Step 1: Celá suite**

Run: `RAILS_ENV=test bundle exec rails test`
Expected: max 4 baseline failures (tep_controller_test user_change_email), žádné nové.

- [ ] **Step 2: Kontrola proti specifikaci** — projít `navrh-kvizy-a-pratele.md` sekce §1-§14 a odškrtat, že každá má implementaci nebo je vědomě odložená (§13). Vědomě NEimplementováno v této fázi: moderační UI pro org (sloupec `hidden` existuje, editace zatím ručně/konzolí), definice kvízů přes admin UI (zakládají se konzolí/seedem), zvýraznění „svítícího" přihlášení nad rámec badge.

- [ ] **Step 3: Doplnit poznámku do `Readme.md`** — sekce o kvízech: odkaz na `navrh-kvizy-a-pratele.md`, jak založit kvíz (`Quiz.create!(name: 'advent-2026', quiz_type: 'advent', opens_on: ..., closes_on: ..., data: {'correct' => {...}})`), jak nasadit adventomat (`data-quiz` na modal), cron pro `rake friends:cleanup`.

- [ ] **Step 4: Commit**

```bash
git add Readme.md
git commit -m "readme: kvizy a pratele pikomatu"
```
