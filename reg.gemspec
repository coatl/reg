# -*- encoding: utf-8 -*-
dir=File.dirname(__FILE__)
require "#{dir}/lib/reg/version"
Reg::Description=open("#{dir}/README"){|f| f.read[/\A.*?\n\n.*?\n\n/m] } #customized
Reg::Latest_changes="###"+open("#{dir}/History.txt"){|f| f.read[/\A===(.*?)(?====)/m,1] }

Gem::Specification.new do |s|
  s.name = "reg"
  s.version = Reg::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Caleb Clausen"]
  s.date = Time.now.strftime("%Y-%m-%d")
  s.email = %q{caleb (at) inforadical (dot) net}
  s.extra_rdoc_files = ["README", "COPYING"]
  s.files = `git ls-files`.split
  s.has_rdoc = true
  s.homepage = %{http://github.com/coatl/reg}
  s.rdoc_options = %w[--main README]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{reg}
  s.rubygems_version = %q{1.3.0}
  s.test_files = %w[test/test_all.rb]
  s.summary = "Reg is a library for pattern matching in ruby data structures."
  s.description = Reg::Description

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<sequence>, [">= 0.2.3"])
    else
      s.add_dependency(%q<sequence>, [">= 0.2.3"])
    end
  else
    s.add_dependency(%q<sequence>, [">= 0.2.3"])
  end
end
