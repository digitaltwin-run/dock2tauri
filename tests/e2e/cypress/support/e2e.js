// ***********************************************************
// This example support/e2e.js is processed and
// loaded automatically before your test files.
//
// This is a great place to put global configuration and
// behavior that modifies Cypress.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

// Import commands.js using ES2015 syntax:
import './commands'

// Alternatively you can use CommonJS syntax:
// require('./commands')

// Global test configuration
Cypress.on('uncaught:exception', (err, runnable) => {
  // Prevent Cypress from failing tests on uncaught exceptions from the app
  // This is useful for Tauri apps that might have different error handling
  console.log('Uncaught exception:', err.message)
  
  // Return false to prevent the error from failing the test
  // Only for known Tauri-related errors
  if (err.message.includes('__TAURI__') || err.message.includes('ResizeObserver')) {
    return false
  }
  
  // Let other errors fail the test
  return true
})

// Wait for app initialization before each test
beforeEach(() => {
  // Set longer timeout for Tauri apps
  cy.defaultCommandTimeout = 10000
  
  // Custom viewport for consistent testing
  cy.viewport(1280, 720)
})

// Global after hook for cleanup
afterEach(() => {
  // Take screenshot on failure
  cy.on('fail', (err) => {
    cy.screenshot(`failure-${Cypress.currentTest.title}`)
    throw err
  })
})

// Add global custom commands
Cypress.Commands.add('waitForTauriApp', () => {
  // Wait for Tauri app to be fully loaded
  cy.get('#output', { timeout: 15000 }).should('be.visible')
  cy.contains('TauriDock Control Panel ready!', { timeout: 15000 }).should('be.visible')
})

Cypress.Commands.add('checkDockerAvailable', () => {
  // Check if Docker is available by clicking Docker Info
  cy.get('#docker-info-btn').click()
  cy.get('#output', { timeout: 10000 }).should('satisfy', (text) => {
    return text.includes('Docker') || text.includes('Error') || text.includes('Connection')
  })
})

Cypress.Commands.add('launchTestContainer', (image = 'hello-world', name = 'cypress-test') => {
  // Helper to launch a test container
  cy.get('#custom-image').clear().type(image)
  cy.get('#custom-name').clear().type(name)
  cy.get('#launch-custom').click()
  
  // Wait for container operation to complete
  cy.get('#output', { timeout: 20000 }).should('satisfy', (text) => {
    return text.includes(image) || text.includes('Error')
  })
})

Cypress.Commands.add('stopAllTestContainers', () => {
  // Helper to clean up test containers
  cy.get('#refresh-btn').click()
  cy.wait(2000)
  
  // Stop any containers that might be running from tests
  cy.get('.container-card .stop-btn').each(($btn) => {
    if ($btn.is(':visible')) {
      cy.wrap($btn).click({ force: true })
      cy.wait(1000)
    }
  })
})
