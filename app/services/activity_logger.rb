# Service to log admin activities
class ActivityLogger
  class << self
    # Log an activity
    # @param user [User] The admin who performed the action
    # @param action [String] The action performed (from ActivityLog::ACTIONS)
    # @param target [ApplicationRecord] The target object (Investor, Request, etc.)
    # @param metadata [Hash] Optional metadata (max 5 keys recommended)
    def log(user:, action:, target:, metadata: {})
      return unless user.present? && action.present? && target.present?

      clean_metadata = metadata.slice(
        :amount, :status, :from, :to, :reason,
        :request_type, :method, :label, :category, :active
      )

      ActivityLog.create!(
        user: user,
        action: action,
        target: target,
        metadata: clean_metadata
      )
    rescue StandardError => e
      # Don't fail the main operation if logging fails
      Rails.logger.error("ActivityLogger failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end

    # Log with automatic inference from changes
    def log_changes(user:, action:, target:, changes: {})
      metadata = {}

      # Extract relevant changes
      changes.each do |key, (from, to)|
        case key.to_s
        when 'status'
          metadata[:from] = from
          metadata[:to] = to
        when 'current_balance', 'amount'
          metadata[:amount] = to
        end
      end

      log(user: user, action: action, target: target, metadata: metadata)
    end
  end
end
