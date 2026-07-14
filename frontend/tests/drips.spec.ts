import { test, expect, Page, Route } from '@playwright/test';

// --- Shared fixtures -------------------------------------------------------

const SEGMENTS = [
  { id: 7, name: 'Sellers', description: null, conditions: { operator: 'and', conditions: [] }, customer_count: 1200, created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
];

const TEMPLATES = [
  { id: 1, name: 'Tenant Welcome', trigger: 'welcome', channel: 'email', subject: 'Welcome', body: '<h1>Welcome {{first_name}}</h1>', body_format: 'html', environment_id: 1, created_at: '', updated_at: '' },
  { id: 2, name: 'Service Reminder', trigger: 'reminder', channel: 'email', subject: 'Reminder', body: '<p>Reminder</p>', body_format: 'html', environment_id: 1, created_at: '', updated_at: '' },
  { id: 3, name: 'Welcome SMS', trigger: 'welcome_sms', channel: 'sms', subject: '', body: 'Hi {{first_name}}', body_format: 'html', environment_id: 1, created_at: '', updated_at: '' },
];

const ATTRIBUTES = [
  { key: 'email', label: 'Email', type: 'string' },
  { key: 'custom.product_uploaded', label: 'product_uploaded', type: 'string' },
];

function dripFixture(overrides: Record<string, unknown> = {}) {
  return {
    id: 5,
    name: 'Seller onboarding',
    status: 'draft',
    segment_id: 7,
    segment: { id: 7, name: 'Sellers' },
    environment_id: 1,
    allow_reentry: false,
    exit_on_segment_leave: true,
    enroll_existing_on_start: true,
    steps: [],
    stats: { active: 0, completed: 0, exited: 0, total: 0 },
    created_at: '2026-06-01T00:00:00Z',
    updated_at: '2026-06-01T00:00:00Z',
    ...overrides,
  };
}

const body = (data: unknown, status = 200) => ({ status, contentType: 'application/json', body: JSON.stringify(data) });

// Only intercept real API calls (fetch/xhr) — never the SPA document navigation
// or Vite's source-module script requests, which share the same dev origin.
const isApi = (route: Route) => ['fetch', 'xhr'].includes(route.request().resourceType());
const api = (data: unknown, status = 200) => async (route: Route) =>
  isApi(route) ? route.fulfill(body(data, status)) : route.continue();

async function authenticate(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem('persist:root', JSON.stringify({
      auth: JSON.stringify({
        isAuthenticated: true,
        user: { id: '1', name: 'Test User', email: 'test@example.com', is_super_admin: false, account_id: '1' },
        account: { id: '1', name: 'Test Account', plan: 'trial', onboarding_completed_at: '2026-01-01T00:00:00Z' },
        token: 'test-token',
      }),
    }));
    window.localStorage.setItem('messy_token', 'test-token');
    window.localStorage.setItem('messy_active_env', '1');
  });
}

// Reference-data routes used across the designer/setup pages.
async function mockReferenceData(page: Page, { segments = SEGMENTS, templates = TEMPLATES } = {}) {
  await page.route('**/segments/attributes', api({ attributes: ATTRIBUTES }));
  await page.route('**/segments', api(segments));
  await page.route('**/templates**', api(templates));
}

test.describe('Drips — index', () => {
  test('shows an empty state when there are no drips', async ({ page }) => {
    await authenticate(page);
    await page.route('**/drips', api([]));
    await page.goto('/drips');

    await expect(page.locator('h1.page-heading')).toContainText('Drips');
    await expect(page.getByText('No drips yet')).toBeVisible();
  });

  test('lists drips with status and stats', async ({ page }) => {
    await authenticate(page);
    await page.route('**/drips', api([
      dripFixture({ status: 'active', stats: { active: 42, completed: 8, exited: 1, total: 51 }, steps: [{ id: 1, position: 0, template_id: 1, channel: 'email', delay_days: 0, conditions: {}, on_fail: 'skip' }] }),
    ]));
    await page.goto('/drips');

    const row = page.getByRole('row', { name: /Seller onboarding/ });
    await expect(row).toContainText('Sellers');
    await expect(row).toContainText('Active');
    await expect(row).toContainText('42');
  });
});

test.describe('Drips — setup step', () => {
  test('prompts to create a segment when none exist', async ({ page }) => {
    await authenticate(page);
    await mockReferenceData(page, { segments: [] });
    await page.goto('/drips/new');

    await expect(page.getByText('No segments yet', { exact: false })).toBeVisible();
    await page.getByRole('button', { name: 'Create a segment' }).click();
    await expect(page).toHaveURL(/\/segments\/new$/);
  });

  test('creates a drip and opens the designer', async ({ page }) => {
    await authenticate(page);
    await mockReferenceData(page);
    await page.route('**/drips/5', api(dripFixture()));
    await page.route('**/drips', async (route) => {
      if (!isApi(route)) return route.continue();
      if (route.request().method() === 'POST') return route.fulfill(body(dripFixture(), 201));
      return route.fulfill(body([]));
    });

    await page.goto('/drips/new');
    await page.fill('#drip-name', 'Seller onboarding');
    await page.getByRole('combobox').first().click();
    await page.getByRole('option', { name: 'Sellers' }).click();
    await page.getByRole('button', { name: /Save & design sequence/ }).click();

    await expect(page).toHaveURL(/\/drips\/5\/edit$/);
  });
});

test.describe('Drips — visual designer', () => {
  test.beforeEach(async ({ page }) => {
    await authenticate(page);
    await mockReferenceData(page);
    await page.route('**/drips/projection', api({
      segment_total: 1200,
      steps: [{ position: 0, reachable: 1200, hitting: 1000, skipped: 200 }],
    }));
    await page.route('**/drips/5/activate', api(dripFixture({ status: 'active' })));
    await page.route('**/drips/5/pause', api(dripFixture({ status: 'paused' })));
  });

  test('renders the sequence canvas with start and end nodes and projection', async ({ page }) => {
    await page.route('**/drips/5', api(dripFixture({
      steps: [{ id: 1, position: 0, template_id: 1, channel: 'email', delay_days: 0, conditions: {}, on_fail: 'skip', template: { id: 1, name: 'Tenant Welcome', channel: 'email' } }],
    })));
    await page.goto('/drips/5/edit');

    await expect(page.getByText(/When customer enters/)).toBeVisible();
    await expect(page.getByText('End of drip')).toBeVisible();
    await expect(page.getByText('1,200 in segment')).toBeVisible();
    await expect(page.getByText('Tenant Welcome')).toBeVisible();
    // shown both on the node and in the projection panel
    await expect(page.getByText(/1,000 receive/).first()).toBeVisible();
  });

  test('adds a step and shows the inspector with channel + template', async ({ page }) => {
    await page.route('**/drips/5', api(dripFixture()));
    await page.goto('/drips/5/edit');

    await page.getByRole('button', { name: 'Email' }).click(); // add an email step from the Actions palette
    const panel = page.getByRole('tabpanel');
    await expect(page.getByText('Step 1')).toBeVisible();
    await expect(panel.getByText('Channel', { exact: true })).toBeVisible();
    await expect(panel.getByText('Template', { exact: true })).toBeVisible();
    await expect(panel.getByRole('button', { name: 'Choose a template…' })).toBeVisible();
  });

  test('shows an empty state for a channel that has no templates', async ({ page }) => {
    await page.route('**/drips/5', api(dripFixture()));
    await page.goto('/drips/5/edit');

    await page.getByRole('button', { name: 'WhatsApp' }).click(); // add a WhatsApp step from the palette
    await expect(page.getByText('No whatsapp templates yet.')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Create a template' })).toBeVisible();
  });

  test('template picker is searchable', async ({ page }) => {
    await page.route('**/drips/5', api(dripFixture()));
    await page.goto('/drips/5/edit');

    await page.getByRole('button', { name: 'Email' }).click(); // add an email step from the palette
    const panel = page.getByRole('tabpanel');
    await panel.getByRole('button', { name: 'Choose a template…' }).click();

    await expect(page.getByText('Tenant Welcome')).toBeVisible();
    await expect(page.getByText('Service Reminder')).toBeVisible();

    await page.getByPlaceholder('Search templates…').fill('reminder');
    await expect(page.getByText('Service Reminder')).toBeVisible();
    await expect(page.getByText('Tenant Welcome')).toHaveCount(0);

    await page.getByText('Service Reminder').click();
    await expect(panel.getByRole('button', { name: 'Service Reminder' })).toBeVisible();
  });

  test('preview is shown in its own tab', async ({ page }) => {
    await page.route('**/drips/5', api(dripFixture({
      steps: [{ id: 1, position: 0, template_id: 1, channel: 'email', delay_days: 0, conditions: {}, on_fail: 'skip', template: { id: 1, name: 'Tenant Welcome', channel: 'email' } }],
    })));
    await page.goto('/drips/5/edit');

    await page.getByRole('button', { name: /Tenant Welcome/ }).first().click();
    await expect(page.getByRole('tab', { name: 'Edit' })).toBeVisible();
    await page.getByRole('tab', { name: 'Preview' }).click();
    await expect(page.locator('iframe[title="Template Preview"]')).toBeVisible();
  });

  test('dragging a palette action onto the canvas adds a step', async ({ page }) => {
    await page.route('**/drips/5', api(dripFixture()));
    await page.goto('/drips/5/edit');

    const dt = await page.evaluateHandle(() => new DataTransfer());
    await page.getByRole('button', { name: 'Email' }).dispatchEvent('dragstart', { dataTransfer: dt });
    // drop zones appear only while dragging
    const zone = page.getByText('Drop here').first();
    await zone.dispatchEvent('dragover', { dataTransfer: dt });
    await zone.dispatchEvent('drop', { dataTransfer: dt });

    // a step now exists and is selected for editing
    await expect(page.getByText('Step 1')).toBeVisible();
  });

  test('dragging a step reorders the sequence', async ({ page }) => {
    await page.route('**/drips/5', api(dripFixture({
      steps: [
        { id: 1, position: 0, template_id: 1, channel: 'email', delay_days: 0, conditions: {}, on_fail: 'skip', template: { id: 1, name: 'Tenant Welcome', channel: 'email' } },
        { id: 2, position: 1, template_id: 2, channel: 'email', delay_days: 0, conditions: {}, on_fail: 'skip', template: { id: 2, name: 'Service Reminder', channel: 'email' } },
      ],
    })));
    await page.goto('/drips/5/edit');

    const first = page.getByRole('button', { name: /Tenant Welcome/ });
    const second = page.getByRole('button', { name: /Service Reminder/ });
    // initially Tenant Welcome is above Service Reminder
    expect((await first.boundingBox())!.y).toBeLessThan((await second.boundingBox())!.y);

    // drag the second card; drop on the first drop zone (before step 0) → moves it before
    const dt = await page.evaluateHandle(() => new DataTransfer());
    await second.dispatchEvent('dragstart', { dataTransfer: dt });
    const zone = page.getByText('Drop here').first();
    await zone.dispatchEvent('dragover', { dataTransfer: dt });
    await zone.dispatchEvent('drop', { dataTransfer: dt });

    // now Service Reminder is above Tenant Welcome
    await expect.poll(async () => {
      const a = (await page.getByRole('button', { name: /Service Reminder/ }).boundingBox())!.y;
      const b = (await page.getByRole('button', { name: /Tenant Welcome/ }).boundingBox())!.y;
      return a < b;
    }).toBe(true);
  });

  test('clicking the canvas background deselects the selected step', async ({ page }) => {
    await page.route('**/drips/5', api(dripFixture({
      steps: [{ id: 1, position: 0, template_id: 1, channel: 'email', delay_days: 0, conditions: {}, on_fail: 'skip', template: { id: 1, name: 'Tenant Welcome', channel: 'email' } }],
    })));
    await page.goto('/drips/5/edit');

    await page.getByRole('button', { name: /Tenant Welcome/ }).first().click();
    await expect(page.getByText('Step 1')).toBeVisible();

    // click empty canvas area (left padding, away from the centered nodes)
    await page.getByTestId('drip-canvas').click({ position: { x: 8, y: 8 } });
    await expect(page.getByText('Step 1')).toHaveCount(0);
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible();
  });

  test('starting a drip confirms (everyone-in-segment), then activates', async ({ page }) => {
    let activated = false;
    await page.route('**/drips/5/activate', async (route) => { activated = true; return route.fulfill(body(dripFixture({ status: 'active' }))); });
    await page.route('**/drips/5', async (route) => {
      if (!isApi(route)) return route.continue();
      if (route.request().method() === 'PUT') return route.fulfill(body(dripFixture()));
      return route.fulfill(body(dripFixture({
        steps: [{ id: 1, position: 0, template_id: 1, channel: 'email', delay_days: 0, conditions: {}, on_fail: 'skip', template: { id: 1, name: 'Tenant Welcome', channel: 'email' } }],
      })));
    });
    await page.goto('/drips/5/edit');

    // wait for the (debounced) projection to load so the count is populated
    await expect(page.getByText('1,200 in segment')).toBeVisible();
    await page.getByRole('button', { name: 'Start drip' }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toContainText('1,200 customers');
    await dialog.getByRole('button', { name: 'Start drip' }).click();

    await expect.poll(() => activated).toBe(true);
    await expect(page.getByRole('button', { name: 'Stop' })).toBeVisible();
  });

  test('a new-entrants-only drip warns differently on start', async ({ page }) => {
    await page.route('**/drips/5', async (route) => {
      if (!isApi(route)) return route.continue();
      if (route.request().method() === 'PUT') return route.fulfill(body(dripFixture({ enroll_existing_on_start: false })));
      return route.fulfill(body(dripFixture({
        enroll_existing_on_start: false,
        steps: [{ id: 1, position: 0, template_id: 1, channel: 'email', delay_days: 0, conditions: {}, on_fail: 'skip', template: { id: 1, name: 'Tenant Welcome', channel: 'email' } }],
      })));
    });
    await page.goto('/drips/5/edit');

    await page.getByRole('button', { name: 'Start drip' }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toContainText('Only customers who enter the segment from now on');
  });
});
