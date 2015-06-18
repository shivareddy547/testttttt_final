# -*- encoding: utf-8 -*-
# stub: simple_enum 1.6.9 ruby lib

Gem::Specification.new do |s|
  s.name = "simple_enum"
  s.version = "1.6.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Lukas Westermann"]
  s.date = "2014-04-29"
  s.description = "Provides enum-like fields for ActiveRecord, ActiveModel and Mongoid models."
  s.email = ["lukas.westermann@gmail.com"]
  s.homepage = "http://lwe.github.com/simple_enum/"
  s.licenses = ["MIT"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.rubygems_version = "2.2.2"
  s.summary = "Simple enum-like field support for models."

  s.installed_by_version = "2.2.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 3.0.0"])
      s.add_development_dependency(%q<rake>, [">= 0.9.2"])
      s.add_development_dependency(%q<minitest>, ["~> 2.0"])
      s.add_development_dependency(%q<activerecord>, [">= 3.0.0"])
      s.add_development_dependency(%q<mongoid>, ["~> 2.0"])
    else
      s.add_dependency(%q<activesupport>, [">= 3.0.0"])
      s.add_dependency(%q<rake>, [">= 0.9.2"])
      s.add_dependency(%q<minitest>, ["~> 2.0"])
      s.add_dependency(%q<activerecord>, [">= 3.0.0"])
      s.add_dependency(%q<mongoid>, ["~> 2.0"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 3.0.0"])
    s.add_dependency(%q<rake>, [">= 0.9.2"])
    s.add_dependency(%q<minitest>, ["~> 2.0"])
    s.add_dependency(%q<activerecord>, [">= 3.0.0"])
    s.add_dependency(%q<mongoid>, ["~> 2.0"])
  end
end
