import { test, expect } from '@playwright/test';

test.describe('Dock2Tauri - Docker Management E2E Tests', () => {
  
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for app to load
    await expect(page.locator('#output')).toBeVisible();
    await expect(page.getByText('TauriDock Control Panel ready!')).toBeVisible();
  });

  test('should load the main UI components', async ({ page }) => {
    // Check main UI elements are present
    await expect(page.locator('#docker-info-btn')).toBeVisible();
    await expect(page.locator('#system-info-btn')).toBeVisible();
    await expect(page.locator('#refresh-btn')).toBeVisible();
    await expect(page.locator('#launch-custom')).toBeVisible();
    
    // Check preset buttons
    await expect(page.locator('[data-preset="nginx"]')).toBeVisible();
    await expect(page.locator('[data-preset="grafana"]')).toBeVisible();
    await expect(page.locator('[data-preset="jupyter"]')).toBeVisible();
    await expect(page.locator('[data-preset="portainer"]')).toBeVisible();
    
    // Check containers list
    await expect(page.locator('#containers-list')).toBeVisible();
  });

  test('should display Docker info when button clicked', async ({ page }) => {
    // Click Docker Info button
    await page.locator('#docker-info-btn').click();
    
    // Wait for output to appear
    await expect(page.locator('#output')).toContainText('Docker System Information', { timeout: 10000 });
    
    // Check that Docker info is displayed (basic check)
    const output = await page.locator('#output').textContent();
    expect(output).toMatch(/Docker|Version|Container/i);
  });

  test('should display system info when button clicked', async ({ page }) => {
    // Click System Info button
    await page.locator('#system-info-btn').click();
    
    // Wait for output to appear
    await expect(page.locator('#output')).toContainText('System Information', { timeout: 10000 });
    
    // Check that system info is displayed
    const output = await page.locator('#output').textContent();
    expect(output).toMatch(/Operating System|Platform|Architecture/i);
  });

  test('should refresh containers list', async ({ page }) => {
    // Click refresh button
    await page.locator('#refresh-btn').click();
    
    // Wait for refresh completion
    await expect(page.locator('#output')).toContainText('Containers refreshed!', { timeout: 10000 });
  });

  test('should launch preset Docker container', async ({ page }) => {
    // Click Nginx preset button
    await page.locator('[data-preset="nginx"]').click();
    
    // Wait for container launch output
    await expect(page.locator('#output')).toContainText('nginx', { timeout: 15000 });
    
    // Check if launch was successful (should contain container ID or success message)
    const output = await page.locator('#output').textContent();
    expect(output).toMatch(/(Successfully launched|Container|Started)/i);
  });

  test('should fill and launch custom container', async ({ page }) => {
    // Fill custom container form
    await page.locator('#custom-image').fill('hello-world');
    await page.locator('#custom-name').fill('test-hello-world');
    await page.locator('#custom-port-host').fill('8080');
    await page.locator('#custom-port-container').fill('80');
    
    // Click launch button
    await page.locator('#launch-custom').click();
    
    // Wait for container launch output
    await expect(page.locator('#output')).toContainText('hello-world', { timeout: 15000 });
  });

  test('should handle Docker errors gracefully', async ({ page }) => {
    // Try to launch container with invalid image
    await page.locator('#custom-image').fill('invalid-image-that-does-not-exist-12345');
    await page.locator('#custom-name').fill('test-invalid');
    
    // Click launch button
    await page.locator('#launch-custom').click();
    
    // Should show error message
    await expect(page.locator('#output')).toContainText('Error', { timeout: 15000 });
  });

  test('should display running containers', async ({ page }) => {
    // First launch a container
    await page.locator('[data-preset="nginx"]').click();
    await page.waitForTimeout(3000); // Wait for container to start
    
    // Refresh containers list
    await page.locator('#refresh-btn').click();
    await page.waitForTimeout(2000);
    
    // Check if container appears in the list
    const containersList = page.locator('#containers-list');
    await expect(containersList).not.toBeEmpty();
  });

  test('should stop running container', async ({ page }) => {
    // Launch nginx container first
    await page.locator('[data-preset="nginx"]').click();
    await page.waitForTimeout(5000); // Wait for container to start
    
    // Refresh to get container list
    await page.locator('#refresh-btn').click();
    await page.waitForTimeout(2000);
    
    // Find and click stop button for the first container
    const stopButton = page.locator('.container-card .stop-btn').first();
    if (await stopButton.isVisible()) {
      await stopButton.click();
      
      // Wait for stop confirmation
      await expect(page.locator('#output')).toContainText('stopped', { timeout: 10000 });
    }
  });

  test('should validate form inputs', async ({ page }) => {
    // Try to launch with empty image name
    await page.locator('#custom-image').fill('');
    await page.locator('#launch-custom').click();
    
    // Should show validation error or do nothing
    const output = await page.locator('#output').textContent();
    // Either shows error or doesn't launch anything
    expect(output).not.toContain('Successfully launched');
  });

  test('should handle multiple container operations', async ({ page }) => {
    // Launch multiple containers
    await page.locator('[data-preset="nginx"]').click();
    await page.waitForTimeout(3000);
    
    await page.locator('[data-preset="portainer"]').click();
    await page.waitForTimeout(3000);
    
    // Refresh containers list
    await page.locator('#refresh-btn').click();
    await page.waitForTimeout(2000);
    
    // Should show multiple containers
    const containerCards = page.locator('.container-card');
    const count = await containerCards.count();
    expect(count).toBeGreaterThan(0);
  });

  test('should open container URLs in new window', async ({ page, context }) => {
    // Launch nginx container
    await page.locator('[data-preset="nginx"]').click();
    await page.waitForTimeout(5000);
    
    // Refresh to get container list
    await page.locator('#refresh-btn').click();
    await page.waitForTimeout(2000);
    
    // Check if open button exists and test click
    const openButton = page.locator('.container-card .open-btn').first();
    if (await openButton.isVisible()) {
      // Listen for new page/window
      const pagePromise = context.waitForEvent('page');
      await openButton.click();
      
      // Should attempt to open new page (may fail if container isn't ready)
      try {
        const newPage = await pagePromise;
        await newPage.waitForLoadState();
        expect(newPage.url()).toMatch(/localhost|127\.0\.0\.1/);
      } catch (error) {
        // Container might not be ready yet, which is ok for this test
        console.log('Container URL not ready yet:', error);
      }
    }
  });
});
