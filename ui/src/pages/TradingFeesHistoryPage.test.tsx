import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { TradingFeesHistoryPage } from './TradingFeesHistoryPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getTradingFees: vi.fn(),
  },
}));

describe('TradingFeesHistoryPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('loads history including voided fees and filters by status', async () => {
    vi.mocked(api.getTradingFees).mockResolvedValue({
      data: [
        {
          id: 'f1',
          investor_id: 'i1',
          investor_name: 'Investor One',
          investor_email: 'one@test.com',
          applied_by_name: 'Admin One',
          period_start: '2025-10-01',
          period_end: '2025-12-31',
          profit_amount: 100,
          fee_percentage: 30,
          fee_amount: 30,
          applied_at: '2025-12-31T19:00:00Z',
          voided_at: null,
        },
        {
          id: 'f2',
          investor_id: 'i2',
          investor_name: 'Investor Two',
          investor_email: 'two@test.com',
          applied_by_name: 'Admin Two',
          period_start: '2026-01-01',
          period_end: '2026-03-31',
          profit_amount: 120,
          fee_percentage: 30,
          fee_amount: 36,
          applied_at: '2026-03-31T19:00:00Z',
          voided_at: '2026-04-01T15:00:00Z',
        },
      ],
      pagination: { page: 1, per_page: 25, total: 2, total_pages: 1 },
    });

    const user = userEvent.setup();
    render(<TradingFeesHistoryPage />);

    await waitFor(() => expect(api.getTradingFees).toHaveBeenCalledWith({ include_voided: true, page: 1, per_page: 25 }));
    expect(screen.getByText('Historial de Trading Fees')).toBeInTheDocument();
    expect(screen.getAllByText('Investor One').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Investor Two').length).toBeGreaterThan(0);

    await user.selectOptions(screen.getByDisplayValue('Todos'), 'VOIDED');
    expect(screen.queryByText('Investor One')).not.toBeInTheDocument();
    expect(screen.getAllByText('Investor Two').length).toBeGreaterThan(0);
  });
});
