if $*==["test"]
  #hack to get 'rake test' to stay in one process
  #which keeps netbeans happy
  $:<<"."
  require "test/test_all.rb"
  Test::Unit::AutoRunner.run
  exit
end