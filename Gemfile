source "http://rubygems.org"

case version = ENV["MONGOID_VERSION"] || "9"
when /9/
  gem "mongoid", "~> 9.0"
when /8/
  gem "mongoid", "~> 8.0"
when /7/
  gem "mongoid", "~> 7.0"
when /6/
  gem "mongoid", "~> 6.0"
when /5/
  gem "mongoid", "~> 5.0"
when /4/
  gem "mongoid", "~> 4.0"
when /3.1.0/
  gem "mongoid", "~> 3.1.0"
when /3.0.0/
  gem "mongoid", "~> 3.0.0"
else
  gem "mongoid", version
end

gemspec

group :test do
  gem "rspec"
end

group :development do
  gem "rubocop"
  gem "mongoid-danger"
end
