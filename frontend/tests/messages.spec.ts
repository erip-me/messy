import { test, expect } from '@playwright/test';

test.describe('Messages Management', () => {
  test.beforeEach(async ({ page }) => {
    // Mock authentication
    await page.addInitScript(() => {
      window.localStorage.setItem('persist:root', JSON.stringify({
        auth: JSON.stringify({
          isAuthenticated: true,
          user: {
            id: '1',
            name: 'Test User',
            email: 'test@example.com',
            is_super_admin: false,
            account_id: '1'
          },
          account: {
            id: '1',
            name: 'Test Account',
            plan: 'trial'
          },
          token: 'test-token'
        })
      }));
    });

    // Mock messages API
    await page.route('**/messages*', async route => {
      if (route.request().method() === 'GET') {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            messages: [
              {
                id: 1,
                type: 'EmailMessage',
                to: 'user@example.com',
                subject: 'Welcome Email',
                status: 'delivered',
                sent_at: '2024-02-23T10:00:00Z',
                environment: { name: 'Production' }
              },
              {
                id: 2,
                type: 'SmsMessage',
                to: '+1234567890',
                body: 'Your verification code is 123456',
                status: 'failed',
                sent_at: '2024-02-23T09:30:00Z',
                environment: { name: 'Development' }
              }
            ],
            meta: {
              total_count: 2,
              current_page: 1,
              total_pages: 1
            }
          })
        });
      } else {
        await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
      }
    });

    await page.goto('/messages');
  });

  test('should display messages list', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Messages');
    await expect(page.locator('[data-testid="messages-table"]')).toBeVisible();
  });

  test('should show message filters', async ({ page }) => {
    await expect(page.locator('[data-testid="channel-filter"]')).toBeVisible();
    await expect(page.locator('[data-testid="status-filter"]')).toBeVisible();
    await expect(page.locator('[data-testid="environment-filter"]')).toBeVisible();
    await expect(page.locator('[data-testid="date-filter"]')).toBeVisible();
  });

  test('should filter messages by channel', async ({ page }) => {
    await page.click('[data-testid="channel-filter"]');
    await page.click('[data-testid="filter-email"]');
    
    // Should show only email messages
    await expect(page.locator('[data-testid="message-1"]')).toBeVisible();
    await expect(page.locator('[data-testid="message-2"]')).not.toBeVisible();
  });

  test('should filter messages by status', async ({ page }) => {
    await page.click('[data-testid="status-filter"]');
    await page.click('[data-testid="filter-delivered"]');
    
    // Should show only delivered messages
    await expect(page.locator('[data-testid="message-1"]')).toBeVisible();
    await expect(page.locator('[data-testid="message-2"]')).not.toBeVisible();
  });

  test('should search messages', async ({ page }) => {
    await page.fill('[data-testid="search-input"]', 'user@example.com');
    await page.press('[data-testid="search-input"]', 'Enter');
    
    // Should filter results
    await expect(page.locator('[data-testid="message-1"]')).toBeVisible();
  });

  test('should open message detail view', async ({ page }) => {
    await page.click('[data-testid="message-1"]');
    
    // Should show message detail modal
    await expect(page.locator('[data-testid="message-detail"]')).toBeVisible();
    await expect(page.locator('text=user@example.com')).toBeVisible();
    await expect(page.locator('text=Welcome Email')).toBeVisible();
  });

  test('should show delivery timeline', async ({ page }) => {
    await page.click('[data-testid="message-1"]');
    
    // Should show delivery status timeline
    await expect(page.locator('[data-testid="delivery-timeline"]')).toBeVisible();
    await expect(page.locator('text=Delivered')).toBeVisible();
  });
});

test.describe('Message Composition', () => {
  test.beforeEach(async ({ page }) => {
    // Mock authentication
    await page.addInitScript(() => {
      window.localStorage.setItem('persist:root', JSON.stringify({
        auth: JSON.stringify({
          isAuthenticated: true,
          user: {
            id: '1',
            name: 'Test User',
            email: 'test@example.com',
            is_super_admin: false,
            account_id: '1'
          },
          account: {
            id: '1',
            name: 'Test Account',
            plan: 'trial'
          },
          token: 'test-token'
        })
      }));
    });

    await page.goto('/messages');
  });

  test('should show compose message button', async ({ page }) => {
    await expect(page.locator('button:has-text("Compose")')).toBeVisible();
  });

  test('should open email compose form', async ({ page }) => {
    await page.click('button:has-text("Compose")');
    await page.click('[data-testid="compose-email"]');
    
    await expect(page.locator('[data-testid="email-compose-form"]')).toBeVisible();
    await expect(page.locator('input[name="to"]')).toBeVisible();
    await expect(page.locator('input[name="subject"]')).toBeVisible();
    await expect(page.locator('textarea[name="body"]')).toBeVisible();
  });

  test('should open SMS compose form', async ({ page }) => {
    await page.click('button:has-text("Compose")');
    await page.click('[data-testid="compose-sms"]');
    
    await expect(page.locator('[data-testid="sms-compose-form"]')).toBeVisible();
    await expect(page.locator('input[name="to"]')).toBeVisible();
    await expect(page.locator('textarea[name="body"]')).toBeVisible();
  });

  test('should open WhatsApp compose form', async ({ page }) => {
    await page.click('button:has-text("Compose")');
    await page.click('[data-testid="compose-whatsapp"]');
    
    await expect(page.locator('[data-testid="whatsapp-compose-form"]')).toBeVisible();
    await expect(page.locator('input[name="to"]')).toBeVisible();
    await expect(page.locator('textarea[name="body"]')).toBeVisible();
  });

  test('should open push notification compose form', async ({ page }) => {
    await page.click('button:has-text("Compose")');
    await page.click('[data-testid="compose-push"]');
    
    await expect(page.locator('[data-testid="push-compose-form"]')).toBeVisible();
    await expect(page.locator('input[name="to"]')).toBeVisible();
    await expect(page.locator('input[name="title"]')).toBeVisible();
    await expect(page.locator('textarea[name="body"]')).toBeVisible();
  });

  test('should send email message', async ({ page }) => {
    await page.click('button:has-text("Compose")');
    await page.click('[data-testid="compose-email"]');
    
    await page.fill('input[name="to"]', 'test@example.com');
    await page.fill('input[name="subject"]', 'Test Subject');
    await page.fill('textarea[name="body"]', 'Test message body');
    
    await page.click('button[type="submit"]:has-text("Send")');
    
    // Should close form and show success message
    await expect(page.locator('[data-testid="email-compose-form"]')).not.toBeVisible();
  });
});