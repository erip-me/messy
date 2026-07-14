# Alba serializes the JSON layer (app/resources/*). The active_support backend
# keeps as_json semantics (ISO8601 timestamps etc.) identical to the previous
# inline render json: calls.
Alba.backend = :active_support
