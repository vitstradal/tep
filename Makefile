restart:
	touch tmp/restart.txt

migrate-prod:
	rake db:migrate RAILS_ENV=production

migrate-devel:
	rake db:migrate RAILS_ENV=development
t:
	rake test
server:
	script/rails server
