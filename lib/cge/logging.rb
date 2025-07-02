module CGE
  # Logging mixins
  module Logging
    LOG_LEVEL_DEBUG = 0
    LOG_LEVEL_INFO = 1
    LOG_LEVEL_WARN = 2
    LOG_LEVEL_ERROR = 3
    LOG_LEVEL_NONE = 4

    def log_debug(message)
      internal_log(message, LOG_LEVEL_DEBUG)
    end

    def log_info(message)
      internal_log(message, LOG_LEVEL_INFO)
    end

    def log_warn(message)
      internal_log(message, LOG_LEVEL_WARN)
    end

    def log_error(message)
      internal_log(message, LOG_LEVEL_ERROR)
    end

    def log_level_to_string(level)
      case level
      when LOG_LEVEL_DEBUG
        'DEBUG'
      when LOG_LEVEL_INFO
        'INFO'
      when LOG_LEVEL_WARN
        'WARN'
      when LOG_LEVEL_ERROR
        'ERROR'
      else
        'NONE'
      end
    end

    def internal_log(message, level)
      return unless CGE.log_level <= level

      puts "[#{log_level_to_string(level)} #{Time.now}] #{message}"
    end
  end
end
