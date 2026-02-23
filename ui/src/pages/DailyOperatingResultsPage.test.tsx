import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { DailyOperatingResultsPage } from './DailyOperatingResultsPage'
import { api } from '../lib/api'

vi.mock('../lib/api', () => ({
  api: {
    previewDailyOperatingResult: vi.fn(),
    createDailyOperatingResult: vi.fn(),
    getDailyOperatingResults: vi.fn().mockResolvedValue({ data: [], meta: { page: 1, per_page: 20, total: 0, total_pages: 0 } }),
  },
}))

describe('DailyOperatingResultsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('runs preview and applies after confirmation', async () => {
    const user = userEvent.setup()

    vi.mocked(api.previewDailyOperatingResult).mockResolvedValueOnce({
      data: {
        date: '2025-12-31',
        percent: 0.1,
        investors_count: 1,
        total_before: 1000,
        total_delta: 1,
        total_after: 1001,
        investors: [
          {
            investor_id: '1',
            investor_name: 'Investor One',
            investor_email: 'one@test.com',
            balance_before: 1000,
            delta: 1,
            balance_after: 1001,
          },
        ],
      },
    })
    vi.mocked(api.createDailyOperatingResult).mockResolvedValueOnce({})

    render(<DailyOperatingResultsPage />)

    const percentInput = screen.getByPlaceholderText('Ej: 0,10')
    await user.clear(percentInput)
    await user.type(percentInput, '0,10')

    const previewBtn = screen.getByRole('button', { name: /Previsualizar/i })
    await user.click(previewBtn)

    await waitFor(() => {
      expect(screen.getByText('Preview')).toBeInTheDocument()
    })

    const applyBtn = screen.getByRole('button', { name: 'Aplicar' })
    await user.click(applyBtn)

    const confirmBtn = screen.getByRole('button', { name: /Confirmar y aplicar/i })
    await user.click(confirmBtn)

    await waitFor(() => {
      expect(api.createDailyOperatingResult).toHaveBeenCalledWith(
        expect.objectContaining({
          percent: 0.1,
        }),
      )
    })
  })

  it('disables apply when preview has zero impacted investors', async () => {
    const user = userEvent.setup()
    vi.mocked(api.previewDailyOperatingResult).mockResolvedValueOnce({
      data: {
        date: '2025-10-07',
        percent: 0.01,
        investors_count: 0,
        total_before: 0,
        total_delta: 0,
        total_after: 0,
        investors: [],
      },
    })

    render(<DailyOperatingResultsPage />)

    const percentInput = screen.getByPlaceholderText('Ej: 0,10')
    await user.clear(percentInput)
    await user.type(percentInput, '0,01')

    const previewBtn = screen.getByRole('button', { name: /Previsualizar/i })
    await user.click(previewBtn)

    await waitFor(() => {
      expect(screen.getByText('Preview')).toBeInTheDocument()
    })

    const applyBtn = screen.getByRole('button', { name: 'Aplicar' })
    expect(applyBtn).toBeDisabled()
    expect(screen.getByText(/No hay inversores activos con capital para esa fecha/i)).toBeInTheDocument()
    expect(api.createDailyOperatingResult).not.toHaveBeenCalled()
  })
})

