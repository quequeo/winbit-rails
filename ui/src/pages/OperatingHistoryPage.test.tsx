import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { OperatingHistoryPage } from './OperatingHistoryPage'
import { api } from '../lib/api'

vi.mock('../lib/api', () => ({
  api: {
    getDailyOperatingResults: vi.fn(),
    getDailyOperatingMonthlySummary: vi.fn(),
    getDailyOperatingByMonth: vi.fn(),
  },
}))

describe('OperatingHistoryPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('loads monthly summary and daily history', async () => {
    vi.mocked(api.getDailyOperatingResults).mockResolvedValueOnce({
      data: [{ id: '1', date: '2025-12-31', percent: 0.1, created_at: '2025-12-31T20:00:00Z' }],
      meta: { page: 1, per_page: 10, total: 1, total_pages: 1 },
    })
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValueOnce({
      data: [
        {
          month: '2025-12',
          days: 2,
          compounded_percent: 1.23,
          first_date: '2025-12-01',
          last_date: '2025-12-31',
        },
      ],
    })

    render(<OperatingHistoryPage />)

    await waitFor(() => {
      expect(screen.getByText('Historial de Operativas')).toBeInTheDocument()
    })

    expect(screen.getByText('Resumen por mes')).toBeInTheDocument()
    expect(screen.getByText(/Dic 2025/i)).toBeInTheDocument()
    expect(screen.getByText('Detalle diario')).toBeInTheDocument()
    expect(screen.getByText('2025-12-31')).toBeInTheDocument()
  })

  it('opens month detail modal', async () => {
    const user = userEvent.setup()
    vi.mocked(api.getDailyOperatingResults).mockResolvedValueOnce({
      data: [],
      meta: { page: 1, per_page: 10, total: 0, total_pages: 1 },
    })
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValueOnce({
      data: [
        {
          month: '2025-12',
          days: 1,
          compounded_percent: 0.5,
          first_date: '2025-12-01',
          last_date: '2025-12-31',
        },
      ],
    })
    vi.mocked(api.getDailyOperatingByMonth).mockResolvedValueOnce({
      data: [{ id: 'd1', date: '2025-12-10', percent: 0.2 }],
    })

    render(<OperatingHistoryPage />)

    await waitFor(() => {
      expect(screen.getByText(/Dic 2025/i)).toBeInTheDocument()
    })

    const viewBtn = screen.getByLabelText('Ver detalle')
    await user.click(viewBtn)

    await waitFor(() => {
      expect(screen.getByText('Detalle del mes')).toBeInTheDocument()
    })
    expect(screen.getByText('2025-12-10')).toBeInTheDocument()
  })
})

