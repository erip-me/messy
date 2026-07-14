import { test, expect } from '@playwright/test';

test.describe('Login Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
  });

  test('should display login form', async ({ page }) => {
    await expect(page.locator('h2')).toContainText('Welcome to Messy');
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('button')).toContainText('Send Magic Link');
  });

  test('should show validation error for invalid email', async ({ page }) => {
    await page.fill('input[type="email"]', 'invalid-email');
    await page.click('button[type="submit"]');
    
    // Browser validation should prevent submission
    const emailInput = page.locator('input[type="email"]');
    const validationMessage = await emailInput.evaluate(el => (el as HTMLInputElement).validationMessage);
    expect(validationMessage).toBeTruthy();
  });

  test('should proceed to token step after valid email submission', async ({ page }) => {
    // Mock the API call
    await page.route('**/magic_links', async route => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ message: 'Magic link sent' })
      });
    });

    await page.fill('input[type="email"]', 'test@example.com');
    await page.click('button[type="submit"]');

    // Should show token input
    await expect(page.locator('input[type="text"]')).toBeVisible();
    await expect(page.locator('label')).toContainText('Magic Link Token');
  });

  test('should allow going back to email step', async ({ page }) => {
    // Mock the API call to get to token step
    await page.route('**/magic_links', async route => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ message: 'Magic link sent' })
      });
    });

    await page.fill('input[type="email"]', 'test@example.com');
    await page.click('button[type="submit"]');
    
    // Click back button
    await page.click('button:has-text("← Back to email")');
    
    // Should show email input again
    await expect(page.locator('input[type="email"]')).toBeVisible();
  });

  test('should login successfully with valid token', async ({ page }) => {
    // Mock magic link API
    await page.route('**/magic_links', async route => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ message: 'Magic link sent' })
      });
    });

    // Mock validation API
    await page.route('**/magic_links/validate*', async route => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
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
          }
        })
      });
    });

    await page.fill('input[type="email"]', 'test@example.com');
    await page.click('button[type="submit"]');
    
    await page.fill('input[type="text"]', 'valid-token');
    await page.click('button[type="submit"]:has-text("Sign In")');

    // Should redirect to dashboard
    await expect(page).toHaveURL('/');
  });
});