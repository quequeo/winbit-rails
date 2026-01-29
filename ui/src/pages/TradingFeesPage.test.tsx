import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { TradingFeesPage } from './TradingFeesPage'
import { api } from '../lib/api'

vi.mock('../lib/api', () => ({
  api: {
    getTradingFeesSummary: vi.fn(),
    calculateTradingFee: vi.fn(),
    applyTradingFee: vi.fn(),
    updateTradingFee: vi.fn(),
    deleteTradingFee: vi.fn(),
  },
}))

describe('TradingFeesPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  const mockRows = [
    {
      investor_id: 'inv-1',
      investor_name: 'Investor One',
      investor_email: 'one@test.com',
      trading_fee_frequency: 'QUARTERLY',
      current_balance: 1080,
      period_start: '2025-10-01',
      period_end: '2025-12-31',
      profit_amount: 100,
      has_profit: true,
      already_applied: true,
      applied_fee_id: 'fee-1',
      applied_fee_amount: 20,
      applied_fee_percentage: 20,
      monthly_profits: [{ month: '2025-10', amount: 10 }],
    },
    {
      investor_id: 'inv-2',
      investor_name: 'Investor Two',
      investor_email: 'two@test.com',
      trading_fee_frequency: 'ANNUAL',
      current_balance: 5000,
      period_start: '2025-01-01',
      period_end: '2025-12-31',
      profit_amount: 200,
      has_profit: true,
      already_applied: false,
      applied_fee_id: null,
      applied_fee_amount: null,
      applied_fee_percentage: null,
      monthly_profits: [{ month: '2025-12', amount: 200 }],
    },
  ] as any

  it('loads and renders investors summary', async () => {
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows)

    render(<TradingFeesPage />)

    await waitFor(() => {
      expect(screen.getByText('Comisiones')).toBeInTheDocument()
    })

    expect(screen.getByText('Investor One')).toBeInTheDocument()
    expect(screen.getByText('Investor Two')).toBeInTheDocument()
  })

  it('filters by investor name/email', async () => {
    const user = userEvent.setup()
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows)

    render(<TradingFeesPage />)

    await waitFor(() => {
      expect(screen.getByText('Investor One')).toBeInTheDocument()
    })

    const filter = screen.getByPlaceholderText('Buscar por nombre o email...')
    await user.type(filter, 'one@test.com')

    expect(screen.getByText('Investor One')).toBeInTheDocument()
    expect(screen.queryByText('Investor Two')).not.toBeInTheDocument()
  })

  it('opens edit modal and calls update', async () => {
    const user = userEvent.setup()
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows)
    vi.mocked(api.updateTradingFee).mockResolvedValueOnce({})

    render(<TradingFeesPage />)

    await waitFor(() => {
      expect(screen.getByText('Investor One')).toBeInTheDocument()
    })

    // Pencil icon button has title="Editar"
    const editBtn = screen.getAllByTitle('Editar')[0]
    await user.click(editBtn)

    const title = screen.getByText('Editar comisión aplicada')
    expect(title).toBeInTheDocument()

    const modal = title.closest('div')!
    const pctInput = within(modal).getByRole('spinbutton') as HTMLInputElement
    await user.clear(pctInput)
    await user.type(pctInput, '30')

    const saveBtn = screen.getByRole('button', { name: 'Guardar' })
    await user.click(saveBtn)

    await waitFor(() => {
      expect(api.updateTradingFee).toHaveBeenCalledWith('fee-1', expect.objectContaining({ fee_percentage: 30 }))
    })
  })

  it('asks confirmation and calls delete', async () => {
    const user = userEvent.setup()
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue(mockRows)
    vi.mocked(api.deleteTradingFee).mockResolvedValueOnce({})

    render(<TradingFeesPage />)

    await waitFor(() => {
      expect(screen.getByText('Investor One')).toBeInTheDocument()
    })

    const trashBtn = screen.getAllByTitle('Eliminar')[0]
    await user.click(trashBtn)

    expect(screen.getByText('Eliminar comisión aplicada')).toBeInTheDocument()

    const confirmButtons = screen.getAllByRole('button', { name: 'Eliminar' })
    const confirm = confirmButtons.find((b) => (b.textContent || '').trim() === 'Eliminar')
    expect(confirm).toBeDefined()
    await user.click(confirm!)

    await waitFor(() => {
      expect(api.deleteTradingFee).toHaveBeenCalledWith('fee-1')
    })
  })
})

