# frozen_string_literal: true

class Jbuilder
  class Blank
    def ==(other)
      super || other.is_a?(Blank)
    end

    def empty?
      true
    end
  end
end
