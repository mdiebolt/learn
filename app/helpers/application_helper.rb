module ApplicationHelper
  # Alert/notice flash rendered in the project's `// message` style.
  # Alert is emitted before notice to match the prior hand-written order.
  def flash_banners
    safe_join(%i[alert notice].filter_map { |kind|
      message = flash[kind]
      tag.p("// #{message}", id: kind, class: "ui-flash ui-flash--#{kind} mb-8") if message
    })
  end

  # The flash-styled validation error list for a record. Renders nothing
  # when the record is absent or valid.
  def error_summary(record)
    return if record.nil? || record.errors.empty?

    tag.div class: "ui-flash ui-flash--alert space-y-1" do
      safe_join(record.errors.full_messages.map { tag.div("// #{it}") })
    end
  end
end
