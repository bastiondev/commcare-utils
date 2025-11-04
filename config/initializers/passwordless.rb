Passwordless.configure do |config|
  config.default_from_address = ENV['EMAILER_FROM']
end