import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { OperativaHubPage } from './OperativaHubPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getDailyOperatingResults: vi.fn(),
    getDailyOperatingMonthlySummary: vi.fn(),
    getDailyOperatingByMonth: vi.fn(),
  },
}));

describe('OperativaHubPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getDailyOperatingResults).mockResolvedValue({ data: [], meta: null } as { data?: unknown[]; meta?: unknown });
    vi.mocked(api.getDailyOperatingMonthlySummary).mockResolvedValue({ data: [] } as { data?: unknown[] });
  });

  it('renders tabs', () => {
    render(
      <MemoryRouter>
        <OperativaHubPage />
      </MemoryRouter>,
    );

    expect(screen.getByRole('button', { name: 'Operativa Diaria' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Historial de Operativas' })).toBeInTheDocument();
  });

  it('switches to historial tab', async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <OperativaHubPage />
      </MemoryRouter>,
    );

    await user.click(screen.getByRole('button', { name: 'Historial de Operativas' }));
    await waitFor(() => expect(api.getDailyOperatingResults).toHaveBeenCalled());
  });
});
