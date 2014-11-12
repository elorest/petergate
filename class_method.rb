module OneM
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def cmethod
      def c_name
        puts self.class.name
      end
    end
  end
end

class One
  # def self.cmethod
  #   def cn
  #     puts "********************************************************************************"
  #     puts self.class.name.to_s
  #   end
  # end
  include OneM
end

class Two < One
  cmethod
end

# class One
#   include OneM
# end
