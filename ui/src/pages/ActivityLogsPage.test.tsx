import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ActivityLogsPage } from './ActivityLogsPage'
import { api } from '../lib/api'

vi.mock('../lib/api', () => ({
  api: {
    getActivityLogs: vi.fn(),
  },
}))

describe('ActivityLogsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('loads and renders activity logs', async () => {
    vi.mocked(api.getActivityLogs).mockResolvedValueOnce({
      data: {
        logs: [
          {
            id: 1,
            action: 'create_investor',
            action_description: 'Crear inversor',
            user: { id: 'u1', name: 'Admin', email: 'admin@test.com' },
            target: { type: 'Investor', id: 'inv1', display: 'Inversor #inv1' },
            metadata: { amount: 100 },
            created_at: '2025-12-31T12:00:00Z',
          },
        ],
        pagination: { page: 1, per_page: 50, total: 1, total_pages: 1 },
      },
    })

    render(<ActivityLogsPage />)

    await waitFor(() => {
      expect(screen.getByText('Registro de Actividad')).toBeInTheDocument()
    })

    expect(screen.getAllByText('Crear inversor').length).toBeGreaterThan(0)
    expect(screen.getAllByText('admin@test.com').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Inversor #inv1').length).toBeGreaterThan(0)
  })

  it('applies filter and refetches', async () => {
    const user = userEvent.setup()
    vi.mocked(api.getActivityLogs).mockResolvedValue({
      data: { logs: [], pagination: { page: 1, per_page: 50, total: 0, total_pages: 1 } },
    })

    render(<ActivityLogsPage />)

    await waitFor(() => {
      expect(screen.getByText('Registro de Actividad')).toBeInTheDocument()
    })

    const filter = screen.getByLabelText('Filtrar por acción')
    await user.selectOptions(filter, 'create_investor')

    await waitFor(() => {
      expect(api.getActivityLogs).toHaveBeenLastCalledWith(expect.objectContaining({ filter_action: 'create_investor' }))
    })
  })
})

