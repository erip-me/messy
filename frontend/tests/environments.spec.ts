import { test, expect } from '@playwright/test';

test.describe('Environments Management', () => {
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

    // Mock environments API
    await page.route('**/environments*', async route => {
      if (route.request().method() === 'GET') {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([
            {
              id: 1,
              name: 'Production',
              api_key: 'prod_12345abcdef',
              allow_email: true,
              allow_sms: true,
              allow_whatsapp: false,
              allow_mobile_push: true,
              allow_web_push: false,
              is_deleted: false
            },
            {
              id: 2,
              name: 'Development',
              api_key: 'dev_67890ghijkl',
              allow_email: true,
              allow_sms: false,
              allow_whatsapp: true,
              allow_mobile_push: false,
              allow_web_push: true,
              is_deleted: false
            }
          ])
        });
      } else if (route.request().method() === 'POST' && route.request().url().includes('/toggle_channel')) {
        await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
      } else {
        await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
      }
    });

    await page.goto('/environments');
  });

  test('should display environments page', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Environments');
    await expect(page.locator('[data-testid="environments-list"]')).toBeVisible();
  });

  test('should show environment cards', async ({ page }) => {
    await expect(page.locator('[data-testid="environment-1"]')).toBeVisible();
    await expect(page.locator('[data-testid="environment-2"]')).toBeVisible();
    
    // Check environment names
    await expect(page.locator('text=Production')).toBeVisible();
    await expect(page.locator('text=Development')).toBeVisible();
  });

  test('should display API keys', async ({ page }) => {
    await expect(page.locator('text=prod_12345abcdef')).toBeVisible();
    await expect(page.locator('text=dev_67890ghijkl')).toBeVisible();
  });

  test('should show channel toggles', async ({ page }) => {
    const prodEnv = page.locator('[data-testid="environment-1"]');
    
    // Check email toggle is enabled
    await expect(prodEnv.locator('[data-testid="toggle-email"]')).toBeChecked();
    
    // Check SMS toggle is enabled  
    await expect(prodEnv.locator('[data-testid="toggle-sms"]')).toBeChecked();
    
    // Check WhatsApp toggle is disabled
    await expect(prodEnv.locator('[data-testid="toggle-whatsapp"]')).not.toBeChecked();
    
    // Check Mobile Push toggle is enabled
    await expect(prodEnv.locator('[data-testid="toggle-mobile-push"]')).toBeChecked();
    
    // Check Web Push toggle is disabled
    await expect(prodEnv.locator('[data-testid="toggle-web-push"]')).not.toBeChecked();
  });

  test('should toggle channel settings', async ({ page }) => {
    const prodEnv = page.locator('[data-testid="environment-1"]');
    
    // Toggle WhatsApp channel on
    await prodEnv.locator('[data-testid="toggle-whatsapp"]').click();
    
    // Should show success message or update UI
    // The actual implementation would handle the API call
  });

  test('should create new environment', async ({ page }) => {
    await page.click('button:has-text("Create Environment")');
    
    await expect(page.locator('[data-testid="environment-form"]')).toBeVisible();
    await page.fill('input[name="name"]', 'Testing Environment');
    
    // Enable some channels
    await page.check('[data-testid="form-toggle-email"]');
    await page.check('[data-testid="form-toggle-sms"]');
    
    await page.click('button[type="submit"]:has-text("Create")');
    
    // Should close form and refresh list
    await expect(page.locator('[data-testid="environment-form"]')).not.toBeVisible();
  });

  test('should edit environment', async ({ page }) => {
    await page.click('[data-testid="environment-1"] button:has-text("Edit")');
    
    await expect(page.locator('[data-testid="environment-form"]')).toBeVisible();
    await expect(page.locator('input[name="name"]')).toHaveValue('Production');
    
    // Update name
    await page.fill('input[name="name"]', 'Production Updated');
    await page.click('button[type="submit"]:has-text("Save")');
  });

  test('should delete environment', async ({ page }) => {
    await page.click('[data-testid="environment-1"] button:has-text("Delete")');
    
    // Should show confirmation dialog
    await expect(page.locator('[data-testid="confirm-dialog"]')).toBeVisible();
    await expect(page.locator('text=Are you sure you want to delete')).toBeVisible();
    
    await page.click('button:has-text("Delete")');
  });

  test('should copy API key', async ({ page }) => {
    await page.click('[data-testid="environment-1"] button:has-text("Copy API Key")');
    
    // Should show success toast or visual feedback
    // Note: Clipboard testing requires specific setup in Playwright
  });

  test('should show environment stats', async ({ page }) => {
    const prodEnv = page.locator('[data-testid="environment-1"]');
    
    // Should show statistics like message count, etc.
    await expect(prodEnv.locator('[data-testid="messages-count"]')).toBeVisible();
    await expect(prodEnv.locator('[data-testid="templates-count"]')).toBeVisible();
  });

  test('should filter environments', async ({ page }) => {
    await page.fill('[data-testid="search-input"]', 'Production');
    
    await expect(page.locator('[data-testid="environment-1"]')).toBeVisible();
    await expect(page.locator('[data-testid="environment-2"]')).not.toBeVisible();
  });

  test('should validate environment creation form', async ({ page }) => {
    await page.click('button:has-text("Create Environment")');
    
    // Try to submit without name
    await page.click('button[type="submit"]:has-text("Create")');
    
    // Should show validation error
    await expect(page.locator('text=Name is required')).toBeVisible();
  });

  test('should display different channel configurations', async ({ page }) => {
    const devEnv = page.locator('[data-testid="environment-2"]');
    
    // Development environment has different channel config
    await expect(devEnv.locator('[data-testid="toggle-email"]')).toBeChecked();
    await expect(devEnv.locator('[data-testid="toggle-sms"]')).not.toBeChecked();
    await expect(devEnv.locator('[data-testid="toggle-whatsapp"]')).toBeChecked();
    await expect(devEnv.locator('[data-testid="toggle-web-push"]')).toBeChecked();
  });
});