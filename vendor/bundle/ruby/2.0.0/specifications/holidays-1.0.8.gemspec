# -*- encoding: utf-8 -*-
# stub: holidays 1.0.8 ruby lib

Gem::Specification.new do |s|
  s.name = "holidays"
  s.version = "1.0.8"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Alex Dunae"]
  s.date = "2014-10-14"
  s.description = "A collection of Ruby methods to deal with statutory and other holidays. You deserve a holiday!"
  s.email = ["code@dunae.ca"]
  s.homepage = "https://github.com/alexdunae/holidays"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.2.2"
  s.summary = "A collection of Ruby methods to deal with statutory and other holidays."

  s.installed_by_version = "2.2.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
    else
      s.add_dependency(%q<bundler>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
    end
  else
    s.add_dependency(%q<bundler>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
  end
end
