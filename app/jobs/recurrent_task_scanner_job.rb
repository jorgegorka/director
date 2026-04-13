class RecurrentTaskScannerJob < ApplicationJob
  queue_as :default

  def perform
    Task.scan_due_recurrences
  end
end
