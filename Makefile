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
void-migrate:
	rake db:migrate RAILS_ENV=void

prod-seed:
	rake db:seed RAILS_ENV=production
dev-seed:
	rake db:seed RAILS_ENV=development
loc-seed:
	rake db:seed RAILS_ENV=local
void-seed:
	rake db:seed RAILS_ENV=void

t:
	rake test
r: restart


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
