require 'csv'

class CustomersController < ApplicationController
  before_action :authenticate_user!

  def index
    customers = current_user.account.customers
    if params[:q].present?
      q = "%#{params[:q]}%"
      customers = customers.where('email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?', q, q, q)
    end
    customers = customers.order(Arel.sql("last_seen_at DESC NULLS LAST, created_at DESC"))
    total = customers.count
    customers = customers.page(params[:page] || 1).per(params[:per_page] || 25)
    render json: {
      customers: CustomerResource.new(customers).to_h,
      total: total,
      page: customers.current_page,
      total_pages: customers.total_pages
    }
  end

  def show
    customer = current_user.account.customers.find(params[:id])

    render json: { customer: CustomerDetailResource.new(customer).to_h }
  end

  def export
    customers = current_user.account.customers
    if params[:q].present?
      q = "%#{params[:q]}%"
      customers = customers.where('email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?', q, q, q)
    end
    # Header pass: pull only the JSONB column to discover custom keys, without
    # instantiating every customer record.
    custom_keys = customers.pluck(:custom_attributes)
                           .flat_map { |attrs| (attrs || {}).keys }.uniq.sort
    base_headers = %w[email first_name last_name phone created_at last_seen_at]

    csv_data = CSV.generate do |csv|
      csv << base_headers + custom_keys
      # find_each batches (1000 rows at a time, ordered by id) so we never hold the
      # whole table in memory — avoids OOM/timeout on large accounts.
      customers.find_each do |c|
        attrs = c.custom_attributes || {}
        csv << [
          c.email, c.first_name, c.last_name, c.phone,
          c.created_at&.iso8601, c.last_seen_at&.iso8601
        ] + custom_keys.map { |k| attrs[k] }
      end
    end

    send_data csv_data,
      filename: "contacts-#{Date.current.iso8601}.csv",
      type: 'text/csv',
      disposition: 'attachment'
  end

  def recent_activities
    activities = current_user.account.customer_activities
      .includes(:customer, :environment)
      .order(created_at: :desc)
      .limit(20)

    render json: {
      activities: activities.map { |a|
        {
          id: a.id,
          activity_type: a.activity_type,
          customer: {
            id: a.customer.id,
            email: a.customer.email,
            first_name: a.customer.first_name,
            last_name: a.customer.last_name
          },
          environment: a.environment&.name,
          properties: a.properties,
          created_at: a.created_at
        }
      }
    }
  end

  def destroy
    customer = current_user.account.customers.find(params[:id])
    customer.destroy
    render json: { message: 'Customer deleted' }
  end

  def toggle_unsubscribe
    customer = current_user.account.customers.find(params[:id])
    channel = params[:channel].to_s
    unless Campaign::CHANNELS.include?(channel)
      return render json: { error: 'Invalid channel' }, status: :unprocessable_entity
    end

    if customer.unsubscribed_from?(channel)
      customer.resubscribe_to!(channel)
      render json: { message: "Resubscribed to #{channel}", unsubscribed_channels: customer.unsubscribed_channels }
    else
      customer.unsubscribe_from!(channel)
      render json: { message: "Unsubscribed from #{channel}", unsubscribed_channels: customer.unsubscribed_channels }
    end
  end

  def toggle_category_unsubscribe
    customer = current_user.account.customers.find(params[:id])
    category = params[:category].presence || Customer::MARKETING_CATEGORY

    if customer.unsubscribed_from_category?(category)
      customer.resubscribe_to_category!(category)
      render json: { message: "Resubscribed to #{category}", unsubscribed_categories: customer.unsubscribed_categories }
    else
      customer.unsubscribe_from_category!(category)
      render json: { message: "Unsubscribed from #{category}", unsubscribed_categories: customer.unsubscribed_categories }
    end
  end

  def unsubscribe_all
    customer = current_user.account.customers.find(params[:id])
    all_unsubscribed = Campaign::CHANNELS.all? { |ch| customer.unsubscribed_from?(ch) }

    if all_unsubscribed
      customer.update!(unsubscribed_channels: customer.unsubscribed_channels.except(*Campaign::CHANNELS))
      render json: { message: "Resubscribed to all channels", unsubscribed_channels: customer.unsubscribed_channels }
    else
      channels = Campaign::CHANNELS.each_with_object({}) { |ch, h| h[ch] = Time.current.iso8601 }
      customer.update!(unsubscribed_channels: customer.unsubscribed_channels.merge(channels))
      render json: { message: "Unsubscribed from all channels", unsubscribed_channels: customer.unsubscribed_channels }
    end
  end
end
