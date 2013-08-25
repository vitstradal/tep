restart:
	touch tmp/restart.txt

migrate-prod:
	rake db:migrate RAILS_ENV=production

migrate-devel:
	rake db:migrate RAILS_ENV=development

seed-prod:
	rake db:seed RAILS_ENV=production
seed-devel:
	rake db:seed RAILS_ENV=development

t:
	rake test
server:
	script/rails server
