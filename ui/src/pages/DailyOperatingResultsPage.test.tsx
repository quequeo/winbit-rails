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
    editPreviewDailyOperatingResult: vi.fn(),
    updateDailyOperatingResult: vi.fn(),
  },
}))

vi.mock('../components/ui/DatePicker', () => ({
  DatePicker: ({ value, onChange }: { value: string; onChange: (v: string) => void }) => (
    <input
      aria-label="Fecha"
      value={value}
      onChange={(e) => onChange(e.target.value)}
    />
  ),
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

  it('shows alert when preview API fails', async () => {
    const user = userEvent.setup()
    vi.mocked(api.previewDailyOperatingResult).mockRejectedValue(new Error('Network error'))

    render(<DailyOperatingResultsPage />)

    await user.clear(screen.getByPlaceholderText('Ej: 0,10'))
    await user.type(screen.getByPlaceholderText('Ej: 0,10'), '0,10')
    await user.click(screen.getByRole('button', { name: /Previsualizar/i }))

    await waitFor(() => {
      expect(screen.getByText('No se pudo previsualizar')).toBeInTheDocument()
      expect(screen.getByText('Network error')).toBeInTheDocument()
    })
  })

  it('shows alert for invalid percent', async () => {
    const user = userEvent.setup()
    render(<DailyOperatingResultsPage />)

    await user.clear(screen.getByPlaceholderText('Ej: 0,10'))
    await user.click(screen.getByRole('button', { name: /Previsualizar/i }))

    await waitFor(() => {
      expect(screen.getByText('Porcentaje inválido')).toBeInTheDocument()
    })
  })

  it('clears preview when Limpiar is clicked', async () => {
    const user = userEvent.setup()
    vi.mocked(api.previewDailyOperatingResult).mockResolvedValueOnce({
      data: {
        date: '2025-12-31',
        percent: 0.1,
        investors_count: 1,
        total_before: 1000,
        total_delta: 1,
        total_after: 1001,
        investors: [{ investor_id: '1', investor_name: 'A', investor_email: 'a@t.com', balance_before: 1000, delta: 1, balance_after: 1001 }],
      },
    })

    render(<DailyOperatingResultsPage />)

    await user.clear(screen.getByPlaceholderText('Ej: 0,10'))
    await user.type(screen.getByPlaceholderText('Ej: 0,10'), '0,10')
    await user.click(screen.getByRole('button', { name: /Previsualizar/i }))

    await waitFor(() => expect(screen.getByText('Preview')).toBeInTheDocument())

    await user.click(screen.getByRole('button', { name: 'Limpiar' }))

    await waitFor(() => {
      expect(screen.queryByText('Preview')).not.toBeInTheDocument()
    })
  })

  it('shows alert when apply fails', async () => {
    const user = userEvent.setup()
    vi.mocked(api.previewDailyOperatingResult).mockResolvedValueOnce({
      data: {
        date: '2025-12-31',
        percent: 0.1,
        investors_count: 1,
        total_before: 1000,
        total_delta: 1,
        total_after: 1001,
        investors: [{ investor_id: '1', investor_name: 'A', investor_email: 'a@t.com', balance_before: 1000, delta: 1, balance_after: 1001 }],
      },
    })
    vi.mocked(api.createDailyOperatingResult).mockRejectedValueOnce(new Error('Apply failed'))

    render(<DailyOperatingResultsPage />)

    await user.clear(screen.getByPlaceholderText('Ej: 0,10'))
    await user.type(screen.getByPlaceholderText('Ej: 0,10'), '0,10')
    await user.click(screen.getByRole('button', { name: /Previsualizar/i }))

    await waitFor(() => expect(screen.getByText('Preview')).toBeInTheDocument())

    await user.click(screen.getByRole('button', { name: 'Aplicar' }))
    await user.click(screen.getByRole('button', { name: /Confirmar y aplicar/i }))

    await waitFor(() => {
      expect(screen.getByText('No se pudo aplicar')).toBeInTheDocument()
      expect(screen.getByText('Apply failed')).toBeInTheDocument()
    })
  })

  it('shows history with pagination', async () => {
    vi.mocked(api.getDailyOperatingResults).mockResolvedValue({
      data: [
        { id: '1', date: '2025-01-15', percent: 0.5, applied_by: { name: 'Admin' } },
      ],
      meta: { page: 1, per_page: 20, total: 25, total_pages: 2 },
    } as never)

    render(<DailyOperatingResultsPage />)

    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument())
    expect(screen.getByText(/Página/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Siguiente' })).toBeInTheDocument()
  })

  it('shows alert for invalid date format', async () => {
    const user = userEvent.setup()
    render(<DailyOperatingResultsPage />)

    await user.clear(screen.getByLabelText('Fecha'))
    await user.type(screen.getByLabelText('Fecha'), '2025/10/10')
    await user.click(screen.getByRole('button', { name: /Previsualizar/i }))

    await waitFor(() => {
      expect(screen.getByText('Fecha inválida')).toBeInTheDocument()
      expect(screen.getByText(/Usá el selector de fecha/i)).toBeInTheDocument()
    })
  })

  it('shows alert for future date', async () => {
    const user = userEvent.setup()
    render(<DailyOperatingResultsPage />)

    await user.clear(screen.getByLabelText('Fecha'))
    await user.type(screen.getByLabelText('Fecha'), '2099-01-01')
    await user.click(screen.getByRole('button', { name: /Previsualizar/i }))

    await waitFor(() => {
      expect(screen.getByText('Fecha inválida')).toBeInTheDocument()
      expect(screen.getByText(/fecha futura/i)).toBeInTheDocument()
    })
  })

  it('hides pagination block when there is only one history page', async () => {
    vi.mocked(api.getDailyOperatingResults).mockResolvedValue({
      data: [{ id: '1', date: '2025-01-15', percent: 0.5, applied_by: { name: 'Admin' } }],
      meta: { page: 1, per_page: 20, total: 1, total_pages: 1 },
    } as never)

    render(<DailyOperatingResultsPage />)

    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument())
    expect(screen.queryByRole('button', { name: 'Anterior' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Siguiente' })).not.toBeInTheDocument()
  })

  it('shows edit button only for today rows', async () => {
    const today = new Date()
    const todayISO = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

    vi.mocked(api.getDailyOperatingResults).mockResolvedValue({
      data: [
        { id: '1', date: todayISO, percent: 0.5, applied_by: { name: 'Admin' } },
        { id: '2', date: '2025-01-01', percent: 0.3, applied_by: { name: 'Admin' } },
      ],
      meta: { page: 1, per_page: 20, total: 2, total_pages: 1 },
    } as never)

    render(<DailyOperatingResultsPage />)

    await waitFor(() => expect(screen.getAllByText('Admin').length).toBeGreaterThan(0))

    const editButtons = screen.getAllByRole('button', { name: 'Editar' })
    expect(editButtons).toHaveLength(1)
  })

  it('opens edit modal and runs edit preview', async () => {
    const user = userEvent.setup()
    const today = new Date()
    const todayISO = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

    vi.mocked(api.getDailyOperatingResults).mockResolvedValue({
      data: [{ id: 'abc', date: todayISO, percent: 1.0, applied_by: { name: 'Admin' } }],
      meta: { page: 1, per_page: 20, total: 1, total_pages: 1 },
    } as never)

    vi.mocked(api.editPreviewDailyOperatingResult).mockResolvedValueOnce({
      data: {
        date: todayISO,
        old_percent: 1.0,
        new_percent: 2.0,
        investors_count: 1,
        total_old_delta: 10.0,
        total_new_delta: 20.0,
        total_difference: 10.0,
        investors: [{ investor_id: '1', investor_name: 'Inv', investor_email: 'inv@test.com', old_delta: 10.0, new_delta: 20.0, difference: 10.0 }],
      },
    })

    render(<DailyOperatingResultsPage />)

    await waitFor(() => expect(screen.getByRole('button', { name: 'Editar' })).toBeInTheDocument())
    await user.click(screen.getByRole('button', { name: 'Editar' }))

    await waitFor(() => expect(screen.getByText('Editar operativa diaria')).toBeInTheDocument())

    const editPercentInput = screen.getAllByPlaceholderText('Ej: 0,10')[1]
    await user.clear(editPercentInput)
    await user.type(editPercentInput, '2,00')
    await user.click(screen.getByRole('button', { name: /Previsualizar cambio/i }))

    await waitFor(() => {
      expect(api.editPreviewDailyOperatingResult).toHaveBeenCalledWith('abc', { percent: 2 })
    })

    expect(screen.getByText('Aplicar cambio')).toBeInTheDocument()
  })

  it('applies edit after confirmation', async () => {
    const user = userEvent.setup()
    const today = new Date()
    const todayISO = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

    vi.mocked(api.getDailyOperatingResults).mockResolvedValue({
      data: [{ id: 'abc', date: todayISO, percent: 1.0, applied_by: { name: 'Admin' } }],
      meta: { page: 1, per_page: 20, total: 1, total_pages: 1 },
    } as never)

    vi.mocked(api.editPreviewDailyOperatingResult).mockResolvedValueOnce({
      data: {
        date: todayISO,
        old_percent: 1.0,
        new_percent: 0.5,
        investors_count: 1,
        total_old_delta: 10.0,
        total_new_delta: 5.0,
        total_difference: -5.0,
        investors: [{ investor_id: '1', investor_name: 'Inv', investor_email: 'inv@test.com', old_delta: 10.0, new_delta: 5.0, difference: -5.0 }],
      },
    })
    vi.mocked(api.updateDailyOperatingResult).mockResolvedValueOnce({})

    render(<DailyOperatingResultsPage />)

    await waitFor(() => expect(screen.getByRole('button', { name: 'Editar' })).toBeInTheDocument())
    await user.click(screen.getByRole('button', { name: 'Editar' }))

    const editPercentInput = screen.getAllByPlaceholderText('Ej: 0,10')[1]
    await user.clear(editPercentInput)
    await user.type(editPercentInput, '0,50')
    await user.click(screen.getByRole('button', { name: /Previsualizar cambio/i }))

    await waitFor(() => expect(screen.getByText('Aplicar cambio')).toBeInTheDocument())
    await user.click(screen.getByText('Aplicar cambio'))

    await waitFor(() => expect(screen.getByText(/Confirmar edición de operativa/i)).toBeInTheDocument())
    await user.click(screen.getByRole('button', { name: /Confirmar edición/i }))

    await waitFor(() => {
      expect(api.updateDailyOperatingResult).toHaveBeenCalledWith('abc', expect.objectContaining({ percent: 0.5 }))
    })
  })
})

