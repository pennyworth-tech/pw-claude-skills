---
name: web-component-testing
description: Web component testing with React Testing Library, Vue Test Utils, and user-centric testing patterns. Use when testing UI components in isolation, implementing component-level tests, or validating user interactions.
license: MIT
version: 1.0.0
category: component-testing
platforms:
  - web
frameworks:
  - React Testing Library
  - Vue Test Utils
  - Jest
  - Vitest
tags:
  - web
  - component-testing
  - react
  - vue
  - testing-library
trust_tier: 3
validation:
  schema_path: schemas/output.schema.json
  validator_path: scripts/validate.sh
  eval_path: evals/eval.yaml
  validation_status: passing
---

# Web Component Testing

Comprehensive patterns for testing UI components with Testing Library and best practices.

## React Testing Library

### Setup
```typescript
// jest.config.js or vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    globals: true
  }
})

// src/test/setup.ts
import '@testing-library/jest-dom'
import { cleanup } from '@testing-library/react'
import { afterEach } from 'vitest'

afterEach(() => {
  cleanup()
})
```

### Basic Component Test
```tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { LoginForm } from './LoginForm'

describe('LoginForm', () => {
  it('should submit form with email and password', async () => {
    const user = userEvent.setup()
    const handleSubmit = vi.fn()

    render(<LoginForm onSubmit={handleSubmit} />)

    // Arrange - find elements by accessible roles
    const emailInput = screen.getByRole('textbox', { name: /email/i })
    const passwordInput = screen.getByLabelText(/password/i)
    const submitButton = screen.getByRole('button', { name: /sign in/i })

    // Act - interact like a real user
    await user.type(emailInput, 'test@example.com')
    await user.type(passwordInput, 'password123')
    await user.click(submitButton)

    // Assert
    expect(handleSubmit).toHaveBeenCalledWith({
      email: 'test@example.com',
      password: 'password123'
    })
  })
})
```

## Query Priority

### Recommended Query Order
```tsx
// 1. Accessible by Everyone (Preferred)
screen.getByRole('button', { name: /submit/i })
screen.getByLabelText(/email address/i)
screen.getByPlaceholderText(/search/i)
screen.getByText(/welcome/i)
screen.getByDisplayValue(/current value/i)

// 2. Semantic Queries
screen.getByAltText(/profile photo/i)
screen.getByTitle(/close modal/i)

// 3. Test IDs (Last Resort)
screen.getByTestId('submit-button')
```

### Query Types
```tsx
// getBy - throws if not found (use for elements that should exist)
const button = screen.getByRole('button')

// queryBy - returns null if not found (use for elements that may not exist)
const error = screen.queryByText(/error/i)
expect(error).not.toBeInTheDocument()

// findBy - async, waits for element (use for elements that appear after async operations)
const result = await screen.findByText(/success/i)

// getAllBy, queryAllBy, findAllBy - for multiple elements
const items = screen.getAllByRole('listitem')
expect(items).toHaveLength(5)
```

## User Event Interactions

### Setup and Basic Interactions
```tsx
import userEvent from '@testing-library/user-event'

describe('UserInteractions', () => {
  it('should handle various interactions', async () => {
    const user = userEvent.setup()

    render(<InteractiveComponent />)

    // Click
    await user.click(screen.getByRole('button'))

    // Double click
    await user.dblClick(screen.getByRole('button'))

    // Right click
    await user.pointer({ keys: '[MouseRight]', target: element })

    // Hover
    await user.hover(screen.getByText('Hover me'))
    await user.unhover(screen.getByText('Hover me'))

    // Type text
    await user.type(screen.getByRole('textbox'), 'Hello World')

    // Clear and type
    await user.clear(screen.getByRole('textbox'))
    await user.type(screen.getByRole('textbox'), 'New value')

    // Tab navigation
    await user.tab()
    expect(screen.getByRole('button')).toHaveFocus()

    // Keyboard shortcuts
    await user.keyboard('{Control>}a{/Control}')  // Ctrl+A
    await user.keyboard('{Enter}')

    // Select options
    await user.selectOptions(
      screen.getByRole('combobox'),
      screen.getByRole('option', { name: 'Option 2' })
    )

    // Upload file
    const file = new File(['content'], 'test.txt', { type: 'text/plain' })
    await user.upload(screen.getByLabelText(/upload/i), file)
  })
})
```

### Clipboard Operations
```tsx
it('should handle copy/paste', async () => {
  const user = userEvent.setup()

  render(<TextEditor />)

  const input = screen.getByRole('textbox')
  await user.type(input, 'Copy this')
  await user.tripleClick(input) // Select all
  await user.copy()
  await user.clear(input)
  await user.paste()

  expect(input).toHaveValue('Copy this')
})
```

## Async Testing

### Waiting for Elements
```tsx
it('should show loading then results', async () => {
  render(<DataFetcher />)

  // Loading state appears
  expect(screen.getByText(/loading/i)).toBeInTheDocument()

  // Wait for results
  await screen.findByText(/results/i, {}, { timeout: 3000 })

  // Loading should be gone
  expect(screen.queryByText(/loading/i)).not.toBeInTheDocument()
})
```

### waitFor and waitForElementToBeRemoved
```tsx
import { waitFor, waitForElementToBeRemoved } from '@testing-library/react'

it('should handle async state changes', async () => {
  render(<AsyncComponent />)

  // Wait for condition
  await waitFor(() => {
    expect(screen.getByText(/success/i)).toBeInTheDocument()
  })

  // Wait for element to disappear
  await waitForElementToBeRemoved(() => screen.queryByText(/loading/i))

  // Custom timeout and interval
  await waitFor(
    () => expect(mockFn).toHaveBeenCalled(),
    { timeout: 5000, interval: 100 }
  )
})
```

## Form Testing

### Form Validation
```tsx
describe('ContactForm', () => {
  it('should show validation errors', async () => {
    const user = userEvent.setup()
    render(<ContactForm />)

    // Submit empty form
    await user.click(screen.getByRole('button', { name: /submit/i }))

    // Check for error messages
    expect(screen.getByText(/email is required/i)).toBeInTheDocument()
    expect(screen.getByText(/name is required/i)).toBeInTheDocument()

    // Fill in invalid email
    await user.type(screen.getByLabelText(/email/i), 'invalid-email')
    await user.click(screen.getByRole('button', { name: /submit/i }))

    expect(screen.getByText(/invalid email format/i)).toBeInTheDocument()
  })

  it('should submit valid form', async () => {
    const user = userEvent.setup()
    const onSubmit = vi.fn()

    render(<ContactForm onSubmit={onSubmit} />)

    await user.type(screen.getByLabelText(/name/i), 'John Doe')
    await user.type(screen.getByLabelText(/email/i), 'john@example.com')
    await user.type(screen.getByLabelText(/message/i), 'Hello!')
    await user.click(screen.getByRole('button', { name: /submit/i }))

    expect(onSubmit).toHaveBeenCalledWith({
      name: 'John Doe',
      email: 'john@example.com',
      message: 'Hello!'
    })
  })
})
```

## Component Mocking

### Mocking Child Components
```tsx
// Avoid testing implementation details - but sometimes needed
vi.mock('./ExpensiveChart', () => ({
  ExpensiveChart: () => <div data-testid="chart-mock">Chart</div>
}))

it('should render with mocked child', () => {
  render(<Dashboard />)
  expect(screen.getByTestId('chart-mock')).toBeInTheDocument()
})
```

### Mocking Hooks
```tsx
vi.mock('./hooks/useAuth', () => ({
  useAuth: () => ({
    user: { id: '1', name: 'Test User' },
    isAuthenticated: true,
    login: vi.fn(),
    logout: vi.fn()
  })
}))

it('should show user info when authenticated', () => {
  render(<UserProfile />)
  expect(screen.getByText('Test User')).toBeInTheDocument()
})
```

### Mocking Context
```tsx
const mockAuthContext = {
  user: { id: '1', name: 'Test' },
  isAuthenticated: true
}

const renderWithAuth = (ui: React.ReactElement) => {
  return render(
    <AuthContext.Provider value={mockAuthContext}>
      {ui}
    </AuthContext.Provider>
  )
}

it('should render with auth context', () => {
  renderWithAuth(<ProtectedComponent />)
  expect(screen.getByText('Welcome, Test')).toBeInTheDocument()
})
```

## Vue Test Utils

### Basic Vue Component Test
```typescript
import { mount } from '@vue/test-utils'
import Counter from './Counter.vue'

describe('Counter', () => {
  it('should increment count on button click', async () => {
    const wrapper = mount(Counter)

    expect(wrapper.text()).toContain('Count: 0')

    await wrapper.find('button').trigger('click')

    expect(wrapper.text()).toContain('Count: 1')
  })
})
```

### Vue with Testing Library
```typescript
import { render, screen } from '@testing-library/vue'
import userEvent from '@testing-library/user-event'
import SearchForm from './SearchForm.vue'

describe('SearchForm', () => {
  it('should emit search event with query', async () => {
    const user = userEvent.setup()
    const { emitted } = render(SearchForm)

    await user.type(screen.getByRole('searchbox'), 'test query')
    await user.click(screen.getByRole('button', { name: /search/i }))

    expect(emitted().search).toBeTruthy()
    expect(emitted().search[0]).toEqual(['test query'])
  })
})
```

## Accessibility Testing

### Integration with jest-axe
```tsx
import { axe, toHaveNoViolations } from 'jest-axe'

expect.extend(toHaveNoViolations)

describe('Accessibility', () => {
  it('should have no accessibility violations', async () => {
    const { container } = render(<LoginForm />)

    const results = await axe(container)

    expect(results).toHaveNoViolations()
  })
})
```

## Snapshot Testing

### Component Snapshots
```tsx
it('should match snapshot', () => {
  const { container } = render(<Card title="Test" description="Description" />)

  expect(container).toMatchSnapshot()
})

// Inline snapshots
it('should match inline snapshot', () => {
  const { container } = render(<Badge type="success">Active</Badge>)

  expect(container.innerHTML).toMatchInlineSnapshot(`
    "<span class="badge badge-success">Active</span>"
  `)
})
```

## Testing Patterns

### Page Object Pattern
```tsx
// test-utils/pages/LoginPage.ts
export class LoginPage {
  private user = userEvent.setup()

  get emailInput() {
    return screen.getByLabelText(/email/i)
  }

  get passwordInput() {
    return screen.getByLabelText(/password/i)
  }

  get submitButton() {
    return screen.getByRole('button', { name: /sign in/i })
  }

  get errorMessage() {
    return screen.queryByRole('alert')
  }

  async login(email: string, password: string) {
    await this.user.type(this.emailInput, email)
    await this.user.type(this.passwordInput, password)
    await this.user.click(this.submitButton)
  }
}

// In test
it('should show error on invalid login', async () => {
  render(<LoginForm />)
  const page = new LoginPage()

  await page.login('invalid@test.com', 'wrong')

  expect(page.errorMessage).toBeInTheDocument()
})
```

### Data-Driven Tests
```tsx
const loginTestCases = [
  { email: '', password: '', error: 'Email is required' },
  { email: 'invalid', password: 'pass', error: 'Invalid email' },
  { email: 'test@test.com', password: '', error: 'Password is required' },
  { email: 'test@test.com', password: 'short', error: 'Password too short' }
]

describe.each(loginTestCases)('Login validation', ({ email, password, error }) => {
  it(`should show "${error}" for email="${email}" password="${password}"`, async () => {
    const user = userEvent.setup()
    render(<LoginForm />)

    if (email) await user.type(screen.getByLabelText(/email/i), email)
    if (password) await user.type(screen.getByLabelText(/password/i), password)
    await user.click(screen.getByRole('button', { name: /submit/i }))

    expect(screen.getByText(new RegExp(error, 'i'))).toBeInTheDocument()
  })
})
```

## Best Practices

1. **Query by role first** - Most accessible and resilient
2. **Avoid test IDs** - Use as last resort only
3. **Use userEvent over fireEvent** - More realistic interactions
4. **Test behavior, not implementation** - What users see, not how it works
5. **Keep tests isolated** - Each test should be independent
6. **Mock sparingly** - Only mock boundaries (APIs, external libs)
7. **Use async properly** - Always await async operations
8. **Test accessibility** - Integrate axe for a11y checks
9. **Avoid snapshot overuse** - Prefer explicit assertions
10. **Write maintainable tests** - Clear, readable, DRY
