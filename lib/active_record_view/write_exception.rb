module ActiveRecordView::WriteException
  def write_exception_logger
    ActionController::Base.logger
  end

  def write_exception(error, size = 5)
    user_backtrace = error.application_backtrace.reject{|i| i =~ %r{^\#\{RAILS_ROOT\}/vendor/}}
    trace = user_backtrace[0,size - 1].join("\n")
    write_exception_logger.error "%s: %s (%s)" % [error.class, error.message, trace]
  end
end
