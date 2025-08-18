// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************

// Docker-specific commands for Dock2Tauri testing
Cypress.Commands.add('waitForDockerResponse', (selector = '#output', timeout = 15000) => {
  cy.get(selector, { timeout }).should('satisfy', (text) => {
    return text.includes('Docker') || text.includes('Container') || text.includes('Error') || text.includes('Successfully')
  })
})

Cypress.Commands.add('launchPresetContainer', (preset) => {
  cy.get(`[data-preset="${preset}"]`).click()
  cy.waitForDockerResponse()
})

Cypress.Commands.add('launchCustomContainer', (options = {}) => {
  const {
    image = 'hello-world',
    name = `test-${Date.now()}`,
    hostPort = '8080',
    containerPort = '80'
  } = options

  cy.get('#custom-image').clear().type(image)
  cy.get('#custom-name').clear().type(name)
  
  if (hostPort) {
    cy.get('#custom-port-host').clear().type(hostPort)
  }
  
  if (containerPort) {
    cy.get('#custom-port-container').clear().type(containerPort)
  }
  
  cy.get('#launch-custom').click()
  cy.waitForDockerResponse()
})

Cypress.Commands.add('stopContainer', (containerName) => {
  // Refresh containers list first
  cy.get('#refresh-btn').click()
  cy.wait(2000)
  
  // Find container by name and stop it
  cy.get('.container-card').contains(containerName).parents('.container-card').within(() => {
    cy.get('.stop-btn').click()
  })
  
  cy.waitForDockerResponse()
})

Cypress.Commands.add('stopAllContainers', () => {
  cy.get('#refresh-btn').click()
  cy.wait(2000)
  
  cy.get('.container-card .stop-btn').each(($btn) => {
    if ($btn.is(':visible')) {
      cy.wrap($btn).click({ force: true })
      cy.wait(1000)
    }
  })
})

Cypress.Commands.add('checkContainerExists', (containerName) => {
  cy.get('#refresh-btn').click()
  cy.wait(2000)
  
  cy.get('#containers-list').should('contain', containerName)
})

Cypress.Commands.add('waitForAppReady', () => {
  cy.get('#output', { timeout: 15000 }).should('be.visible')
  cy.contains('TauriDock Control Panel ready!', { timeout: 15000 }).should('be.visible')
  
  // Wait for any initial loading to complete
  cy.wait(2000)
})

Cypress.Commands.add('checkDockerStatus', () => {
  cy.get('#docker-info-btn').click()
  cy.waitForDockerResponse()
  
  // Return whether Docker is available
  cy.get('#output').then(($output) => {
    const text = $output.text()
    return !text.includes('Error') && !text.includes('Connection refused')
  })
})

Cypress.Commands.add('clearOutput', () => {
  cy.get('#output').then(($output) => {
    $output.text('')
  })
})

Cypress.Commands.add('assertOutputContains', (text, options = {}) => {
  const { timeout = 10000, caseInsensitive = false } = options
  
  cy.get('#output', { timeout }).should('satisfy', (outputText) => {
    if (caseInsensitive) {
      return outputText.toLowerCase().includes(text.toLowerCase())
    }
    return outputText.includes(text)
  })
})

Cypress.Commands.add('assertOutputNotContains', (text, options = {}) => {
  const { timeout = 5000, caseInsensitive = false } = options
  
  cy.get('#output', { timeout }).should('satisfy', (outputText) => {
    if (caseInsensitive) {
      return !outputText.toLowerCase().includes(text.toLowerCase())
    }
    return !outputText.includes(text)
  })
})

// UI interaction helpers
Cypress.Commands.add('clickAndWait', (selector, waitTime = 1000) => {
  cy.get(selector).click()
  cy.wait(waitTime)
})

Cypress.Commands.add('typeAndWait', (selector, text, waitTime = 500) => {
  cy.get(selector).clear().type(text)
  cy.wait(waitTime)
})

// Error handling commands
Cypress.Commands.add('skipIfDockerUnavailable', () => {
  cy.checkDockerStatus().then((isAvailable) => {
    if (!isAvailable) {
      cy.log('Docker not available, skipping test')
      cy.skip()
    }
  })
})

// Screenshot helpers
Cypress.Commands.add('screenshotOnError', (testName) => {
  cy.on('fail', () => {
    cy.screenshot(`error-${testName}-${Date.now()}`)
  })
})

// Network and timing helpers
Cypress.Commands.add('waitForNetworkIdle', (timeout = 5000) => {
  cy.wait(timeout)
})

Cypress.Commands.add('retryCommand', (command, maxRetries = 3) => {
  let attempts = 0
  
  const attemptCommand = () => {
    attempts++
    try {
      return command()
    } catch (error) {
      if (attempts < maxRetries) {
        cy.wait(1000)
        return attemptCommand()
      }
      throw error
    }
  }
  
  return attemptCommand()
})

// Validation helpers
Cypress.Commands.add('validateFormField', (selector, validValue, invalidValue = '') => {
  // Test valid value
  cy.get(selector).clear().type(validValue)
  cy.get(selector).should('have.value', validValue)
  
  // Test invalid value if provided
  if (invalidValue) {
    cy.get(selector).clear().type(invalidValue)
    // Add specific validation checks based on field type
  }
})

Cypress.Commands.add('validateButtonEnabled', (selector) => {
  cy.get(selector).should('be.visible').and('not.be.disabled')
})

Cypress.Commands.add('validateButtonDisabled', (selector) => {
  cy.get(selector).should('be.visible').and('be.disabled')
})

// Container lifecycle helpers
Cypress.Commands.add('containerLifecycleTest', (containerConfig) => {
  const { image, name, hostPort, containerPort } = containerConfig
  
  // Launch container
  cy.launchCustomContainer({ image, name, hostPort, containerPort })
  cy.assertOutputContains('Successfully', { timeout: 20000 })
  
  // Verify container is running
  cy.checkContainerExists(name)
  
  // Stop container
  cy.stopContainer(name)
  cy.assertOutputContains('stopped', { timeout: 10000 })
})

// Performance testing helpers
Cypress.Commands.add('measureResponseTime', (action, maxTime = 10000) => {
  const startTime = Date.now()
  
  action()
  
  cy.then(() => {
    const endTime = Date.now()
    const responseTime = endTime - startTime
    cy.log(`Response time: ${responseTime}ms`)
    expect(responseTime).to.be.lessThan(maxTime)
  })
})

//
// -- This is a parent command --
// Cypress.Commands.add('login', (email, password) => { ... })
//
//
// -- This is a child command --
// Cypress.Commands.add('drag', { prevSubject: 'element'}, (subject, options) => { ... })
//
//
// -- This is a dual command --
// Cypress.Commands.add('dismiss', { prevSubject: 'optional'}, (subject, options) => { ... })
//
//
// -- This will overwrite an existing command --
// Cypress.Commands.overwrite('visit', (originalFn, url, options) => { ... })
