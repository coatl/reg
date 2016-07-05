=begin copyright
    reg - the ruby extended grammar
    Copyright (C) 2016  Caleb Clausen

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
=end
name=Reg
lname=reg
gemname=reg

#everything after this line is generic

version=$(shell ruby -r ./lib/$(lname)/version.rb -e "puts $(name)::VERSION")
filelist=$(shell git ls-files)

.PHONY: all test docs gem tar pkg email
all: test

test:
	ruby -Ilib test/test_all.rb

docs:
	rdoc lib/*

pkg: gem tar

gem:
	gem build $(lname).gemspec

tar:
	tar cf - $(filelist) | ( mkdir $(gemname)-$(version); cd $(gemname)-$(version); tar xf - )
	tar czf $(gemname)-$(version).tar.gz $(gemname)-$(version)
	rm -rf $(gemname)-$(version)

email: README.txt History.txt
	ruby -e ' \
  require "rubygems"; \
  load "./$(lname).gemspec"; \
  spec= Gem::Specification.list.find{|x| x.name=="$(gemname)"}; \
  puts "\
Subject: [ANN] $(name) #{spec.version} Released \
\n\n$(name) version #{spec.version} has been released! \n\n\
#{Array(spec.homepage).map{|url| " * #{url}\n" }} \
 \n\
#{$(name)::Description} \
\n\nChanges:\n\n \
#{$(name)::Latest_changes} \
"\
'
