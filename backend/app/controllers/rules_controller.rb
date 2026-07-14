class RulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  before_action :set_rule, only: %i[show update destroy]

  # GET /rules
  def index
    @rules = if params[:environment_id]
      @account.environments.find(params[:environment_id]).rules.all
    else
      @account.rules.all
    end

    render json: RuleResource.new(@rules).serialize
  end

  # GET /rules/1
  def show
    render json: RuleResource.new(@rule).to_h
  end

  # POST /rules
  def create
    body = JSON.parse(request.body.read)

    # Map frontend 'email' → 'EmailRule' STI type
    if body['type'].present? && !body['type'].end_with?('Rule')
      body['type'] = Rule::TYPE_MAP[body['type']] || body['type'].classify + 'Rule'
    end

    # Map frontend outcome ('block' → 'deny', 'deliver' → 'allow')
    if body['outcome'].present?
      body['outcome'] = Rule::OUTCOME_MAP[body['outcome']] || body['outcome']
    end

    environment_id = body.delete('environment_id')
    @rule = @account.rules.new(body.slice('type', 'name', 'condition', 'outcome', 'tags', 'redirect_to', 'active', 'scope'))

    if environment_id
      @rule.environment = @account.environments.find(environment_id)
    else
      @rule.environment = @account.environments.last
    end

    if @rule.save
      Analytics.track("rule_created", account: @account, user: current_user,
                      properties: { rule_id: @rule.id, type: @rule.type, outcome: @rule.outcome })
      render json: RuleResource.new(@rule).to_h, status: :created
    else
      render json: @rule.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /rules/1
  def update
    body = rule_params.to_h

    # Map outcome if present
    if body['outcome'].present?
      body['outcome'] = Rule::OUTCOME_MAP[body['outcome']] || body['outcome']
    end

    if @rule.update(body)
      render json: RuleResource.new(@rule).to_h
    else
      render json: @rule.errors, status: :unprocessable_entity
    end
  end

  # DELETE /rules/1
  def destroy
    @rule.destroy!
  end

  private

  def set_account
    @account = current_user.account
  end

  def set_rule
    @rule = @account.rules.find(params[:id])
  end

  def rule_params
    params.require(:rule).permit(:name, :condition, :outcome, :redirect_to, :tags, :active, :scope)
  end

end
