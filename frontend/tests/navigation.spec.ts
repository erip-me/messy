import { test, expect } from '@playwright/test';

test.describe('Navigation', () => {
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

    await page.goto('/');
  });

  test('should display sidebar with navigation items', async ({ page }) => {
    // Check main navigation items
    await expect(page.locator('nav a:has-text("Dashboard")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Templates")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Messages")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Environments")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Integrations")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Delivery Rules")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Webhooks")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Live Activity")')).toBeVisible();
    await expect(page.locator('nav a:has-text("User Management")')).toBeVisible();
  });

  test('should navigate to different pages', async ({ page }) => {
    // Navigate to Templates
    await page.click('nav a:has-text("Templates")');
    await expect(page).toHaveURL('/templates');
    await expect(page.locator('h1')).toContainText('Templates');

    // Navigate to Messages
    await page.click('nav a:has-text("Messages")');
    await expect(page).toHaveURL('/messages');
    await expect(page.locator('h1')).toContainText('Messages');

    // Navigate to Environments
    await page.click('nav a:has-text("Environments")');
    await expect(page).toHaveURL('/environments');
    await expect(page.locator('h1')).toContainText('Environments');
  });

  test('should highlight active navigation item', async ({ page }) => {
    // Dashboard should be active by default
    const dashboardLink = page.locator('nav a:has-text("Dashboard")');
    await expect(dashboardLink).toHaveClass(/bg-accent/);

    // Navigate to Templates and check active state
    await page.click('nav a:has-text("Templates")');
    const templatesLink = page.locator('nav a:has-text("Templates")');
    await expect(templatesLink).toHaveClass(/bg-accent/);
    await expect(dashboardLink).not.toHaveClass(/bg-accent/);
  });

  test('should display user info in sidebar', async ({ page }) => {
    await expect(page.locator('text=Test User')).toBeVisible();
    await expect(page.locator('text=test@example.com')).toBeVisible();
    await expect(page.locator('text=Test Account')).toBeVisible();
  });
});

test.describe('Super Admin Navigation', () => {
  test.beforeEach(async ({ page }) => {
    // Mock super admin authentication
    await page.addInitScript(() => {
      window.localStorage.setItem('persist:root', JSON.stringify({
        auth: JSON.stringify({
          isAuthenticated: true,
          user: {
            id: '1',
            name: 'Super Admin',
            email: 'admin@example.com',
            is_super_admin: true,
            account_id: '1'
          },
          account: {
            id: '1',
            name: 'Admin Account',
            plan: 'enterprise'
          },
          token: 'admin-token'
        })
      }));
    });

    await page.goto('/');
  });

  test('should display super admin navigation items', async ({ page }) => {
    await expect(page.locator('nav a:has-text("Tenant Management")')).toBeVisible();
    await expect(page.locator('nav a:has-text("Global Users")')).toBeVisible();
    await expect(page.locator('text=Super Admin')).toBeVisible();
  });

  test('should navigate to super admin pages', async ({ page }) => {
    await page.click('nav a:has-text("Tenant Management")');
    await expect(page).toHaveURL('/admin/accounts');
    await expect(page.locator('h1')).toContainText('Tenant Management');

    await page.click('nav a:has-text("Global Users")');
    await expect(page).toHaveURL('/admin/users');
    await expect(page.locator('h1')).toContainText('Global Users');
  });
});