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
    child_conditions = Array(group["conditions"])
    return scope if child_conditions.empty?

    sql_parts = child_conditions.map { |c| leaf_sql(scope.klass, c) }.compact
    return scope if sql_parts.empty?

    if group["operator"] == "or"
      combined_sql = sql_parts.map { |s| "(#{s})" }.join(" OR ")
      scope.where(combined_sql)
    else
      sql_parts.each { |s| scope = scope.where(s) }
      scope
    end
  end

  def leaf_sql(klass, condition)
    return nil if condition["attribute"].blank? || condition["operator"].blank?

    attr = condition["attribute"].to_s
    op   = condition["operator"].to_s
    val  = ActiveRecord::Base.connection.quote(condition["value"].to_s)
    col  = column_expr(attr)
    return nil if col.nil?

    case op
    when "equals"       then "#{col} = #{val}"
    when "not_equals"   then "#{col} != #{val}"
    when "contains"     then "#{col} ILIKE #{ActiveRecord::Base.connection.quote('%' + condition['value'].to_s + '%')}"
    when "not_contains" then "#{col} NOT ILIKE #{ActiveRecord::Base.connection.quote('%' + condition['value'].to_s + '%')}"
    when "greater_than" then "#{col} > #{val}"
    when "less_than"    then "#{col} < #{val}"
    when "after"        then "#{col}::date > #{val}"
    when "before"       then "#{col}::date < #{val}"
    when "is_blank"     then "(#{col} IS NULL OR #{col} = '')"
    when "is_present"   then "(#{col} IS NOT NULL AND #{col} != '')"
    end
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
      "\"customers\".\"custom_attributes\"->>'#{safe_key}'"
    end
  end
end
