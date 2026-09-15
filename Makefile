restart:
	touch tmp/restart.txt

prod-migrate:
	rake db:migrate RAILS_ENV=production

loc-reset: loc-del loc-migrate loc-seed
dev-reset: dev-del dev-migrate dev-seed
prod-reset: prod-del prod-migrate prod-seed

#prod-del:
#	rm -f db/production.sqlite3
dev-del:
	rm -f var/db/development.sqlite3
loc-del:
	rm -f var/db/local.sqlite3
void-del:
	rm -f var/db/void.sqlite3
dev-migrate:
	rake db:migrate RAILS_ENV=development
loc-migrate:
	rake db:migrate RAILS_ENV=local

loc-migrate-down:
	rake db:rollback RAILS_ENV=local STEP=1
dev-migrate-down:
	rake db:rollback RAILS_ENV=development STEP=1

dev-convert-booleans:
	rake db:convert_booleans RAILS_ENV=development
prod-convert-booleans:
	rake db:convert_booleans RAILS_ENV=production

void-migrate:
	rake db:migrate RAILS_ENV=void

prod-seed:
	rake db:seed RAILS_ENV=production

# Založ/uprav kvíz v produkci. Použití:
#   make prod-quiz-create NAME=tabor2026 TITLE='Tábor 2026 A'
#   make prod-quiz-create NAME=advent2026 TYPE=advent TITLE='Adventní kalendář 2026'
#   make prod-quiz-create NAME=sranda PUBLIC=1 TITLE='Sranda anketa'
prod-quiz-create:
	rake quiz:create RAILS_ENV=production NAME='$(NAME)' TITLE='$(TITLE)' TYPE='$(TYPE)' PUBLIC='$(PUBLIC)'

# Registrace OIDC klienta (Doorkeeper app) pro službu přihlašovanou přes tep.
# Vypíše client_id/secret. Např. OxiCloud pod /sklepox:
#   make prod-oidc-register NAME=oxicloud \
#     REDIRECT_URI=https://pikomat.mff.cuni.cz/sklepox/api/auth/oidc/callback
prod-oidc-register:
	rake oidc:register RAILS_ENV=production NAME='$(NAME)' REDIRECT_URI='$(REDIRECT_URI)'

# Instalace/aktualizace zálohovacího systému (pouštět pod rootem na
# pikomatu). Skript + fix-perms + systemd unity; konfigurák
# /etc/pikomat-zaloha.conf nechává být, založí ho jen napoprvé.
install-pikomat-zalohy:
	@test "$$(id -u)" = 0 || { echo "pust pod rootem"; exit 1; }
	install -m 755 script/pikomat-zaloha.py /usr/local/sbin/pikomat-zaloha.py
	install -m 755 script/pikomat-fix-perms.py /usr/local/sbin/pikomat-fix-perms.py
	test -e /etc/pikomat-zaloha.conf || install -m 644 script/pikomat-zaloha.conf /etc/pikomat-zaloha.conf
	install -m 644 script/pikomat-zaloha.service script/pikomat-zaloha.timer /etc/systemd/system/
	rm -f /usr/local/sbin/pikomat-zaloha.sh
	systemctl daemon-reload
	systemctl enable --now pikomat-zaloha.timer
	@systemctl list-timers 'pikomat-zaloha*' --no-pager | head -2


# Komprese PDF řešení uzavřeného ročníku (ori i rev; gzip, tep čte
# transparentně). Čistý ruby skript bez Rails/rake — jde pustit pod
# kýmkoli, kdo smí zapisovat do var/uploads.
# Použití: make prod-compress-pdfs ROC=40
prod-compress-pdfs:
	@test -n "$(ROC)" || { echo "pouziti: make prod-compress-pdfs ROC=40"; exit 1; }
	ruby script/compress-pdfs.rb $(ROC)
dev-seed:
	rake db:seed RAILS_ENV=development
loc-seed:
	rake db:seed RAILS_ENV=local
void-seed:
	rake db:seed RAILS_ENV=void

t:
	rake test
r: restart

# Spuštění testů. Pozor: projekt běží na rvm Ruby 3.2.1 (ne na systémovém ruby).
# Celá suite:            make test
# Jeden soubor:          make test T=test/functional/tep_controller_test.rb
# Jeden test (řádek):    make test T=test/functional/tep_controller_test.rb:35
.PHONY: test
test:
	RAILS_ENV=test bundle exec rails test $(T)


prod:
	rails c -e production
loc:
	rails c -e local
dev:
	rails c -e development

server: loc-dirs
	script/rails server -e local --binding=localhost

loc-dirs: ../piki ../web ../wikuk ../tepmac

../piki:
	@echo missing ../piki
	@echo TRY: git clone ssh+git://pikomat.mff.cuni.cz:/home/www/git/piki ../piki
	@false
../web:
	@echo missing ../web
	@echo TRY: git clone ssh+git://pikomat.mff.cuni.cz:/home/www/git/web ../web
	@false
../tepmac:
	@echo missing ../tepmac
	@echo TRY: git clone ssh+git://pikomat.mff.cuni.cz:/home/www/git/tepmac ../tepmac
	@false
../wikuk:
	@echo missing ../wikuk
	@echo TRY: mkdir ../wikuk
	@false

void-server: void-dir
	script/rails server -e void --binding=localhost

void-dir: tmp/void/index.wiki

tmp/void/index.wiki:
	mkdir -p tmp/void
	echo '== void edition ==' > tmp/void/index.wiki

ttest:
	rake test
.PHONY: doc
doc:
	rdoc app -o public/tep-doc

aesop:
	rails  r  -e production script/aesop.rb
ctags:
	ctags -R app config lib

gen-secret-key-base:
	script/gen_secret_key_base.rb

gen-oidc-signing-key:
	script/gen_oidc_signing_key.rb
adventomat:
	rails runner -e production script/adventomat.rb

