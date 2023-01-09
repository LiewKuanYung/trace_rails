require "rainbow"

module TracerLogger
  module ColorLog
    def log_color(message, bg = nil, message2 = nil)
      message = Rainbow(message)
      message = message.bg(bg) if bg

      puts "\n\n"
      if message.kind_of? String  
        puts "----------"*5
        puts message
        puts message2 if message2
        puts "----------"*5
      else
        puts "Error Logging Message".red
      end
      puts"\n\n"
    end

    def log_klass_and_path(klass, path)
      if klass.present? and path.present?
        if path.start_with? "app/controllers"
          klass = color(klass, :violet) 
        elsif path.start_with? "app/models"
          klass = color(klass, :green)
        elsif path.start_with? "lib/"
          klass = color(klass, :darkseagreen)
        elsif path.start_with? "<", "("
          klass = color(klass, :darkred)
        end
        puts klass + color(" >> ", :gold) + path
      else
        puts color("Undefined klass or path", :red)
      end
    end

    private

    def color(message, color)
      Rainbow("#{message}").color(color)
    end
  end
end
