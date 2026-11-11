web: bundle exec puma -w 2 -p $PORT -e $RAILS_ENV
worker: bundle exec good_job start
release: bundle exec rake db:migrate