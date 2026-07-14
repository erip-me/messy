# Deep-permit the segment condition tree fed to SegmentEvaluator. A plain
# `permit(keys)` drops the nested `conditions` array (it's an array of hashes,
# not a scalar), which silently empties the group — so the segment would match
# EVERY customer. Recurse through groups, keeping only known leaf/group keys.
#
# Shared by SegmentsController (segment definitions) and DripsController (per-step
# entry conditions + projection) so both sanitize the same DSL identically.
module SegmentConditions
  module_function

  def permit(raw)
    raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    return {} unless raw.is_a?(Hash)
    raw = raw.deep_stringify_keys

    out = {}
    out["operator"] = raw["operator"].to_s if raw["operator"].present?
    if raw["conditions"].is_a?(Array)
      out["conditions"] = raw["conditions"].filter_map do |c|
        c = c.to_unsafe_h if c.respond_to?(:to_unsafe_h)
        next unless c.is_a?(Hash)
        c = c.deep_stringify_keys
        if c["conditions"].is_a?(Array)
          permit(c)
        else
          c.slice("attribute", "operator", "value", "id")
        end
      end
    end
    out
  end
end
