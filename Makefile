restart:
	touch tmp/restart.txt
migrate:
	rake db:migrate RAILS_ENV=production
