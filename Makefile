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
	rm -f db/development.sqlite3
loc-del:
	rm -f db/local.sqlite3
dev-migrate:
	rake db:migrate RAILS_ENV=development
loc-migrate:
	rake db:migrate RAILS_ENV=local

prod-seed:
	rake db:seed RAILS_ENV=production
dev-seed:
	rake db:seed RAILS_ENV=development
loc-seed:
	rake db:seed RAILS_ENV=local

t:
	rake test
r: restart


prod:
	rails c -e production
loc:
	rails c -e local
dev:
	rails c -e development

server:
	script/rails server -e local --binding=localhost
ttest:
	rake test
.PHONY: doc
doc:
	yardoc -r Readme.md
	#yardoc -m markdown -r Readme.md
