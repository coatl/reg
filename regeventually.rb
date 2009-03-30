module Reg
  module Eventually
    class <<self
      def method_missing
        huh
      end
    end
  end
end