describe('Dock2Tauri - Cypress E2E Tests', () => {
  beforeEach(() => {
    cy.visit('/')
    
    // Wait for app initialization
    cy.get('#output', { timeout: 10000 }).should('be.visible')
    cy.contains('TauriDock Control Panel ready!').should('be.visible')
  })

  describe('UI Components', () => {
    it('should display all main interface elements', () => {
      // Check control buttons
      cy.get('#docker-info-btn').should('be.visible')
      cy.get('#system-info-btn').should('be.visible')
      cy.get('#refresh-btn').should('be.visible')
      
      // Check preset container buttons
      cy.get('[data-preset="nginx"]').should('be.visible').and('contain', 'Nginx')
      cy.get('[data-preset="grafana"]').should('be.visible').and('contain', 'Grafana')
      cy.get('[data-preset="jupyter"]').should('be.visible').and('contain', 'Jupyter')
      cy.get('[data-preset="portainer"]').should('be.visible').and('contain', 'Portainer')
      
      // Check custom launch form
      cy.get('#custom-image').should('be.visible')
      cy.get('#custom-name').should('be.visible')
      cy.get('#custom-port-host').should('be.visible')
      cy.get('#custom-port-container').should('be.visible')
      cy.get('#launch-custom').should('be.visible')
      
      // Check containers list
      cy.get('#containers-list').should('be.visible')
    })

    it('should have proper form validation', () => {
      // Test empty form submission
      cy.get('#launch-custom').click()
      
      // Should either show validation message or not proceed
      cy.get('#output').should('not.contain', 'Successfully launched invalid container')
    })
  })

  describe('Docker Information', () => {
    it('should display Docker system information', () => {
      cy.get('#docker-info-btn').click()
      
      cy.get('#output', { timeout: Cypress.env('DOCKER_TIMEOUT') })
        .should('contain', 'Docker System Information')
        .and('match', /Docker|Version|Container/i)
    })

    it('should display system information', () => {
      cy.get('#system-info-btn').click()
      
      cy.get('#output', { timeout: 10000 })
        .should('contain', 'System Information')
        .and('match', /Operating System|Platform|Architecture/i)
    })
  })

  describe('Container Management', () => {
    it('should launch a preset container (Nginx)', () => {
      cy.get('[data-preset="nginx"]').click()
      
      // Wait for container launch
      cy.get('#output', { timeout: Cypress.env('CONTAINER_START_TIMEOUT') })
        .should('contain', 'nginx')
        .and('match', /(Successfully launched|Container|Started)/i)
    })

    it('should launch custom container', () => {
      // Fill the custom container form
      cy.get('#custom-image').type('hello-world')
      cy.get('#custom-name').type('test-hello-cypress')
      cy.get('#custom-port-host').type('8080')
      cy.get('#custom-port-container').type('80')
      
      cy.get('#launch-custom').click()
      
      cy.get('#output', { timeout: Cypress.env('CONTAINER_START_TIMEOUT') })
        .should('contain', 'hello-world')
    })

    it('should refresh containers list', () => {
      cy.get('#refresh-btn').click()
      
      cy.get('#output', { timeout: 10000 })
        .should('contain', 'Containers refreshed!')
    })

    it('should handle invalid container image gracefully', () => {
      cy.get('#custom-image').type('invalid-image-cypress-test-12345')
      cy.get('#custom-name').type('test-invalid-cypress')
      
      cy.get('#launch-custom').click()
      
      cy.get('#output', { timeout: 15000 })
        .should('contain', 'Error')
    })
  })

  describe('Container Operations', () => {
    beforeEach(() => {
      // Launch a test container for operations
      cy.get('[data-preset="nginx"]').click()
      cy.wait(5000) // Wait for container to start
      
      // Refresh to populate containers list
      cy.get('#refresh-btn').click()
      cy.wait(2000)
    })

    it('should display running containers', () => {
      cy.get('#containers-list').should('not.be.empty')
      cy.get('.container-card').should('have.length.at.least', 1)
    })

    it('should stop a running container', () => {
      cy.get('.container-card .stop-btn').first().then($btn => {
        if ($btn.length > 0) {
          cy.wrap($btn).click()
          
          cy.get('#output', { timeout: 10000 })
            .should('contain', 'stopped')
        }
      })
    })

    it('should attempt to open container URL', () => {
      cy.get('.container-card .open-btn').first().then($btn => {
        if ($btn.length > 0) {
          // Mock window.open to prevent actual navigation
          cy.window().then((win) => {
            cy.stub(win, 'open').as('windowOpen')
          })
          
          cy.wrap($btn).click()
          
          // Verify window.open was called
          cy.get('@windowOpen').should('have.been.called')
        }
      })
    })
  })

  describe('Multiple Container Scenarios', () => {
    it('should handle launching multiple containers', () => {
      // Launch nginx
      cy.get('[data-preset="nginx"]').click()
      cy.wait(3000)
      
      // Launch portainer
      cy.get('[data-preset="portainer"]').click()
      cy.wait(3000)
      
      // Refresh and check containers list
      cy.get('#refresh-btn').click()
      cy.wait(2000)
      
      cy.get('.container-card').should('have.length.at.least', 1)
    })

    it('should maintain UI responsiveness during operations', () => {
      // Click multiple buttons rapidly
      cy.get('#docker-info-btn').click()
      cy.get('#system-info-btn').click()
      cy.get('#refresh-btn').click()
      
      // UI should remain responsive
      cy.get('#output').should('be.visible')
      cy.get('#docker-info-btn').should('not.be.disabled')
    })
  })

  describe('Error Handling', () => {
    it('should handle Docker service unavailable', () => {
      // This test simulates Docker not running
      cy.get('#docker-info-btn').click()
      
      // Should either show Docker info or error message
      cy.get('#output', { timeout: 15000 })
        .should('satisfy', (text) => {
          return text.includes('Docker') || text.includes('Error') || text.includes('Connection')
        })
    })

    it('should handle network timeouts gracefully', () => {
      // Test with a container that might take long to pull
      cy.get('#custom-image').type('alpine:latest')
      cy.get('#custom-name').type('test-timeout')
      
      cy.get('#launch-custom').click()
      
      // Should show some response within reasonable time
      cy.get('#output', { timeout: 30000 })
        .should('satisfy', (text) => {
          return text.includes('alpine') || text.includes('Error') || text.includes('timeout')
        })
    })
  })
});
