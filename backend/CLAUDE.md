# Messy Backend - Multi-Channel Messaging Platform

This is a Ruby on Rails 8.0 API-only application that serves as a sophisticated multi-channel messaging platform with webhook integration capabilities.

## Technology Stack

- **Framework**: Ruby on Rails 8.0.5 (API-only mode)
- **Database**: PostgreSQL with Active Record
- **Background Jobs**: Solid Queue (database-backed, no Redis)
- **Real-time**: ActionCable WebSocket support via Solid Cable (database-backed)
- **Authentication**: JWT tokens and API key authentication
- **Templating**: Liquid template engine

## Core Architecture

### Multi-Tenant Structure
- **Accounts**: Top-level tenant containers
- **Environments**: Isolated workspaces within accounts with separate API keys
- **Users**: Account members with magic link authentication

### Message Processing Pipeline
1. **Creation**: Messages created via REST API or webhook triggers
2. **Templating**: Liquid template rendering with dynamic data
3. **Rule Evaluation**: Conditional delivery logic based on recipient/content
4. **Background Processing**: Solid Queue jobs handle asynchronous delivery
5. **Multi-Channel Delivery**: Route through configured integrations

### Database Schema Overview

**Core Tables:**
- `accounts` - Tenant organizations
- `environments` - Isolated workspaces with channel permissions
- `users` - Account members with magic link auth
- `messages` - Multi-type messages with STI pattern
- `templates` - Reusable Liquid templates
- `rules` - Conditional delivery logic
- `integrations` - External service configurations
- `webhooks` - Incoming webhook handlers
- `deliveries` - Message delivery tracking

## Key Features

### Multi-Channel Messaging
- **Email**: SES and SMTP integrations
- **SMS**: Twilio integration
- **WhatsApp**: Twilio Business API
- **Push Notifications**: Mobile and web push support

### Webhook System
- Dynamic URL generation with secure hash routing
- Request filtering (IP allowlists, referer validation)
- Configurable sink processing architecture
- Comprehensive request/response logging

### Template Engine
- Liquid templating for dynamic content
- Variable substitution from webhook/API data
- Template validation and error handling

### Security Features
- API key authentication per environment
- Request validation and content filtering
- SSL enforcement
- Suspicious pattern detection and blocking

## Development Commands

### Setup
```bash
bundle install
rails db:create db:migrate
rails db:schema:load:queue   # Load Solid Queue tables
rails db:schema:load:cable   # Load Solid Cable tables
```

### Running Services
```bash
# Start Rails server
rails server

# Start Solid Queue for background jobs
bin/jobs
```

### Database Operations
```bash
# Run migrations
rails db:migrate

# Seed data
rails db:seed

# Reset database
rails db:reset
```

### Testing
```bash
# Note: Test framework disabled in generators
# Check test directory for existing test files
```

## API Endpoints

### Core Resources
- `GET|POST /accounts` - Account management
- `GET|POST /environments` - Environment management  
- `GET|POST /users` - User management
- `GET|POST|PUT|DELETE /messages` - Message CRUD
- `POST /messages/trigger` - Template-based message creation
- `GET|POST /templates` - Template management
- `GET|POST /rules` - Rule management
- `GET|POST /integrations` - Integration configuration

### Authentication
- `POST /magic_links` - Generate magic login links
- `GET /magic_links/validate` - Validate magic links
- `DELETE /magic_links/logout` - Logout

### Webhooks
- `POST /webhooks/:url_hash` - Webhook callback endpoint

### Monitoring
- `/up` - Health check endpoint

## Background Jobs

### ProcessMessageJob
Evaluates delivery rules and queues message delivery jobs for approved recipients.

### DeliverMessageJob  
Handles actual message delivery through configured integrations.

### ExecuteSinkJob
Processes webhook sink configurations (email notifications, external API calls, etc.).

## Configuration

### Environment Variables
- Database configuration in `config/database.yml`
- AWS credentials for SES integration
- Twilio credentials for SMS/WhatsApp

### Key Files
- `config/application.rb` - Main application configuration
- `config/routes.rb` - API routing
- `config/queue.yml` - Solid Queue configuration
- `config/cable.yml` - Solid Cable configuration
- `Procfile` - Process definitions for deployment

## Deployment Notes

- Configured for SSL enforcement
- Solid Queue uses the same PostgreSQL database (no Redis needed)
- Uses Foreman for process management in production
- ActionCable uses Solid Cable (database-backed, no Redis needed)
- File uploads handled via Active Storage (local storage configured)

## Security Considerations

The webhook controller includes several security measures:
- IP and referer validation
- Custom parameter filtering (blocks suspicious patterns)
- Content validation (uppercase character limits)
- Request logging for audit trails

## Development Tips

- ActionCable broadcasts message updates in real-time
- All message types inherit from base Message model using STI
- Integration configurations stored as JSONB for flexibility
