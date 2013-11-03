restart:
	touch tmp/restart.txt

prod-migrate:
	rake db:migrate RAILS_ENV=production

dev-reset: dev-del dev-migrate dev-seed
prod-reset: prod-del prod-migrate prod-seed

prod-del:
	rm -f db/production.sqlite3
dev-del:
	rm -f db/development.sqlite3
dev-migrate:
	rake db:migrate RAILS_ENV=development

prod-seed:
	rake db:seed RAILS_ENV=production
dev-seed:
	rake db:seed RAILS_ENV=development

t:
	rake test
r: restart
server:
	script/rails server --binding=localhost
