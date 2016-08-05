# -*- encoding: utf-8 -*-
# stub: writeexcel 1.0.5 ruby lib

Gem::Specification.new do |s|
  s.name = "writeexcel"
  s.version = "1.0.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Hideo NAKAMURA"]
  s.date = "2014-12-27"
  s.description = "Multiple worksheets can be added to a workbook and formatting can be applied to cells. Text, numbers, formulas, hyperlinks and images can be written to the cells."
  s.email = ["cxn03651@msj.biglobe.ne.jp"]
  s.extra_rdoc_files = ["LICENSE.txt", "README.rdoc"]
  s.files = ["LICENSE.txt", "README.rdoc"]
  s.homepage = "http://github.com/cxn03651/writeexcel#readme"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.4.8"
  s.summary = "Write to a cross-platform Excel binary file."

  s.installed_by_version = "2.4.8" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<test-unit>, [">= 0"])
      s.add_development_dependency(%q<simplecov>, [">= 0"])
    else
      s.add_dependency(%q<test-unit>, [">= 0"])
      s.add_dependency(%q<simplecov>, [">= 0"])
    end
  else
    s.add_dependency(%q<test-unit>, [">= 0"])
    s.add_dependency(%q<simplecov>, [">= 0"])
  end
end
