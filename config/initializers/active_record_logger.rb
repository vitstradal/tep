

class CacheFreeLogger < ::Logger
  def debug(message, *args, &block)
      super unless message.include? 'CACHE'
  end
end

# Overwrite ActiveRecord’s logger
#ActiveRecord::Base.logger = ActiveSupport::TaggedLogging.new(CacheFreeLogger.new("log/database.log"))
#ActiveRecord::Base.logger = ActiveSupport::TaggedLogging.new(Logger.new("log/database.log"))


