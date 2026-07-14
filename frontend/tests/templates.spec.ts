import { test, expect } from '@playwright/test';

test.describe('Templates Management', () => {
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

    // Mock templates API
    await page.route('**/templates', async route => {
      if (route.request().method() === 'GET') {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([
            {
              id: 1,
              name: 'Welcome Email',
              trigger: 'welcome',
              subject: 'Welcome to our platform!',
              body: 'Welcome {{name}}!',
              folder_id: null
            },
            {
              id: 2,
              name: 'Password Reset',
              trigger: 'reset_password',
              subject: 'Reset your password',
              body: 'Click here to reset: {{reset_link}}',
              folder_id: 1
            }
          ])
        });
      } else {
        await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
      }
    });

    // Mock folders API
    await page.route('**/folders*', async route => {
      if (route.request().method() === 'GET') {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([
            {
              id: 1,
              name: 'User Management',
              parent_folder_id: null,
              templates: []
            }
          ])
        });
      } else {
        await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
      }
    });

    await page.goto('/templates');
  });

  test('should display templates page', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Templates');
    // Should show template list or folders view
    await expect(page.locator('[data-testid="templates-container"]')).toBeVisible();
  });

  test('should display create template button', async ({ page }) => {
    await expect(page.locator('button:has-text("Create Template")')).toBeVisible();
  });

  test('should open template creation modal', async ({ page }) => {
    await page.click('button:has-text("Create Template")');
    
    // Should show template form
    await expect(page.locator('[data-testid="template-form"]')).toBeVisible();
    await expect(page.locator('input[name="name"]')).toBeVisible();
    await expect(page.locator('input[name="trigger"]')).toBeVisible();
    await expect(page.locator('input[name="subject"]')).toBeVisible();
  });

  test('should create new template', async ({ page }) => {
    await page.click('button:has-text("Create Template")');
    
    await page.fill('input[name="name"]', 'Test Template');
    await page.fill('input[name="trigger"]', 'test_trigger');
    await page.fill('input[name="subject"]', 'Test Subject');
    await page.fill('textarea[name="body"]', 'Hello {{name}}!');
    
    await page.click('button[type="submit"]:has-text("Create")');
    
    // Should close modal and refresh list
    await expect(page.locator('[data-testid="template-form"]')).not.toBeVisible();
  });

  test('should edit existing template', async ({ page }) => {
    // Click edit on first template
    await page.click('[data-testid="template-1"] button:has-text("Edit")');
    
    // Should show template form with existing data
    await expect(page.locator('input[name="name"]')).toHaveValue('Welcome Email');
    await expect(page.locator('input[name="trigger"]')).toHaveValue('welcome');
    
    // Update name
    await page.fill('input[name="name"]', 'Updated Welcome Email');
    await page.click('button[type="submit"]:has-text("Save")');
  });

  test('should delete template', async ({ page }) => {
    // Click delete on first template
    await page.click('[data-testid="template-1"] button:has-text("Delete")');
    
    // Should show confirmation dialog
    await expect(page.locator('[data-testid="confirm-dialog"]')).toBeVisible();
    await page.click('button:has-text("Delete")');
  });
});

test.describe('Folder Management', () => {
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

    await page.goto('/templates');
  });

  test('should create new folder', async ({ page }) => {
    await page.click('button:has-text("Create Folder")');
    
    await page.fill('input[name="name"]', 'New Folder');
    await page.click('button[type="submit"]:has-text("Create")');
  });

  test('should move template to folder', async ({ page }) => {
    // This would test drag and drop functionality
    // For now, we'll test the move button approach
    await page.click('[data-testid="template-1"] button:has-text("Move")');
    
    // Should show folder selection
    await expect(page.locator('[data-testid="folder-selector"]')).toBeVisible();
    await page.click('[data-testid="folder-1"]');
    await page.click('button:has-text("Move")');
  });

  test('should navigate folder breadcrumbs', async ({ page }) => {
    // Click on a folder
    await page.click('[data-testid="folder-1"]');
    
    // Should show breadcrumb navigation
    await expect(page.locator('[data-testid="breadcrumbs"]')).toBeVisible();
    await expect(page.locator('text=User Management')).toBeVisible();
    
    // Click back to root
    await page.click('[data-testid="breadcrumbs"] a:has-text("Templates")');
  });
});