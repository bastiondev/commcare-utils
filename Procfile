web: bundle exec puma -t 4:8 -w 2  -p $PORT -e $RAILS_ENV
worker: bundle exec good_job start
release: bundle exec rake db:migrate