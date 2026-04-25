# frozen_string_literal: true

class String
  def compact
    self.gsub(/\s+/, ' ')
  end
end
