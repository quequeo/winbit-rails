import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { ComisionesHubPage } from './ComisionesHubPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getTradingFeesSummary: vi.fn(),
    getAdminInvestors: vi.fn(),
    getReferralCommissions: vi.fn(),
    getTradingFees: vi.fn(),
  },
}));

describe('ComisionesHubPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getTradingFeesSummary).mockResolvedValue([] as unknown);
    vi.mocked(api.getAdminInvestors).mockResolvedValue({ data: [] } as { data?: unknown[] });
    vi.mocked(api.getReferralCommissions).mockResolvedValue({
      data: [],
      pagination: { page: 1, per_page: 20, total: 0, total_pages: 0 },
    } as { data?: unknown[]; pagination?: unknown });
    vi.mocked(api.getTradingFees).mockResolvedValue({ data: [] } as { data?: unknown[] });
  });

  it('renders tabs', () => {
    render(
      <MemoryRouter>
        <ComisionesHubPage />
      </MemoryRouter>,
    );

    expect(screen.getByRole('button', { name: 'Comisiones por período' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Comisiones por referido' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Historial de Comisiones' })).toBeInTheDocument();
  });

  it('switches to referido tab', async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <ComisionesHubPage />
      </MemoryRouter>,
    );

    await user.click(screen.getByRole('button', { name: 'Comisiones por referido' }));
    await waitFor(() => expect(screen.getByText(/Cargá un monto puntual al balance/)).toBeInTheDocument());
  });
});
