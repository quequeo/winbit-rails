import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { ReferralCommissionsPage } from './ReferralCommissionsPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getAdminInvestors: vi.fn(),
    getReferralCommissions: vi.fn(),
    applyReferralCommission: vi.fn(),
  },
}));

describe('ReferralCommissionsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getAdminInvestors).mockResolvedValue({
      data: [
        { id: '1', email: 'inv@test.com', name: 'Investor One' },
        { id: '2', email: 'inv2@test.com', name: 'Investor Two' },
      ],
    } as { data?: unknown[] });
    vi.mocked(api.getReferralCommissions).mockResolvedValue({
      data: [],
      pagination: { page: 1, per_page: 20, total: 0, total_pages: 0 },
    } as { data?: unknown[]; pagination?: unknown });
  });

  it('renders page title and loads investors', async () => {
    render(<ReferralCommissionsPage />);

    expect(screen.getByText('Comisiones por referido')).toBeInTheDocument();
    expect(screen.getByText(/Cargá un monto puntual al balance/)).toBeInTheDocument();

    await waitFor(() => {
      expect(api.getAdminInvestors).toHaveBeenCalled();
      expect(api.getReferralCommissions).toHaveBeenCalled();
    });
  });

  it('shows apply button and history section', async () => {
    render(<ReferralCommissionsPage />);

    await waitFor(() => expect(api.getAdminInvestors).toHaveBeenCalled());

    expect(screen.getByRole('button', { name: /Aplicar comisión/i })).toBeInTheDocument();
    expect(screen.getByText('Historial')).toBeInTheDocument();
  });
});
