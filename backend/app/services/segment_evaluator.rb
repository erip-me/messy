class SegmentEvaluator
  def initialize(base_scope, conditions_hash)
    @base_scope = base_scope
    @conditions_hash = conditions_hash
  end

  def evaluate
    return @base_scope if @conditions_hash.blank? || @conditions_hash["conditions"].blank?
    apply_group(@base_scope, @conditions_hash)
  end

  def count
    evaluate.count
  end

  private

  def apply_group(scope, group)
    sql = group_sql(scope.klass, group)
    sql ? scope.where(sql) : scope
  end

  # Nested groups (the builder's "add group") recurse; an empty group adds no constraint.
  def group_sql(klass, group)
    parts = Array(group["conditions"]).filter_map do |c|
      c["conditions"].is_a?(Array) ? group_sql(klass, c) : leaf_sql(klass, c)
    end
    return nil if parts.empty?

    parts.map { |s| "(#{s})" }.join(group["operator"] == "or" ? " OR " : " AND ")
  end

  def leaf_sql(klass, condition)
    return nil if condition["attribute"].blank? || condition["operator"].blank?

    attr = condition["attribute"].to_s
    op   = condition["operator"].to_s
    val  = ActiveRecord::Base.connection.quote(condition["value"].to_s)
    col  = column_expr(attr)
    return nil if col.nil?

    # Date conditions saved before "on" existed used "equals" with a calendar day.
    op = "on" if op == "equals" && (attr == "created_at" || attr.end_with?("_at")) && condition["value"].to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    case op
    when "equals"       then "#{col} = #{val}"
    when "not_equals"   then "#{col} != #{val}"
    when "contains"     then "#{col} ILIKE #{ActiveRecord::Base.connection.quote('%' + condition['value'].to_s + '%')}"
    when "not_contains" then "#{col} NOT ILIKE #{ActiveRecord::Base.connection.quote('%' + condition['value'].to_s + '%')}"
    when "greater_than" then "#{col} > #{val}"
    when "less_than"    then "#{col} < #{val}"
    # The comparison date comes from the builder's date input; an empty or bad one
    # (a freshly picked attribute) matches no one instead of failing the cast.
    when "on", "after", "before"
      day = Date.iso8601(condition["value"].to_s) rescue nil
      return "FALSE" unless day&.year&.between?(1, 9999) # Postgres has no year 0
      "#{day_expr(col)} #{{ "on" => "=", "after" => ">", "before" => "<" }[op]} '#{day.iso8601}'::date"
    # Rolling windows: value is a day count, so the segment stays current as time passes.
    # A bad count matches no one (FALSE), never everyone: dropping the condition would
    # turn a one-condition segment into "all customers".
    when "more_than_days_ago", "less_than_days_ago"
      days = Integer(condition["value"].to_s, exception: false)
      return "FALSE" if days.nil? || days.negative? || days > MAX_DAYS
      cutoff = "NOW() - INTERVAL '#{days} days'"
      d = date_expr(col)
      op == "more_than_days_ago" ? "#{d} < #{cutoff}" : "#{d} BETWEEN #{cutoff} AND NOW()"
    when "is_blank"     then "(#{col} IS NULL OR #{col} = '')"
    when "is_present"   then "(#{col} IS NOT NULL AND #{col} != '')"
    end
  end

  # Only a real ISO date/time is cast; anything else becomes NULL, because one bad
  # custom value would otherwise fail the whole query (Postgres has no try-cast).
  # The regex bounds month and day; the inner CASE rejects days past month end
  # (2026-02-30), and nesting the CASEs keeps make_date from seeing a bad month.
  ISO_TS = '^[1-9][0-9]{3}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])' \
           '([T ]([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9](\\.[0-9]+)?)?(Z|[+-](0[0-9]|1[0-5])(:?[0-5][0-9])?)?)?$'.freeze

  MAX_DAYS = 36_500 # 100 years; far beyond any real window, well inside Postgres interval range

  # Calendar day as written in the value (2026-01-01T23:30-05:00 is January 1),
  # not shifted into the database's timezone. NULL unless the value is a valid date.
  def day_expr(col)
    "(CASE WHEN #{date_expr(col)} IS NOT NULL THEN substr(#{col}::text, 1, 10)::date END)"
  end

  def date_expr(col)
    t = "#{col}::text"
    month_end = "EXTRACT(DAY FROM make_date(substr(#{t}, 1, 4)::int, substr(#{t}, 6, 2)::int, 1) + INTERVAL '1 month - 1 day')"
    "(CASE WHEN #{t} ~ '#{ISO_TS}' THEN " \
      "(CASE WHEN substr(#{t}, 9, 2)::int <= #{month_end} THEN #{t}::timestamptz END) END)"
  end

  def column_expr(attr)
    case attr
    when "email"      then '"customers"."email"'
    when "first_name" then '"customers"."first_name"'
    when "last_name"  then '"customers"."last_name"'
    when "created_at" then '"customers"."created_at"'
    when /\Acustom\./
      key = attr.sub("custom.", "")
      safe_key = key.gsub("'", "''")
      "(\"customers\".\"custom_attributes\"->>'#{safe_key}')"
    end
  end
end
