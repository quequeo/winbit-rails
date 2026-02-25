import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { AdminsHubPage } from './AdminsHubPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getAdminAdmins: vi.fn(),
    getAdminSession: vi.fn(),
    getAdminSettings: vi.fn(),
    getDepositOptions: vi.fn(),
  },
}));

describe('AdminsHubPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getAdminAdmins).mockResolvedValue({ data: [] } as { data?: unknown[] });
    vi.mocked(api.getAdminSession).mockResolvedValue({ data: { email: 'a@test.com' } } as { data?: unknown });
    vi.mocked(api.getAdminSettings).mockResolvedValue({
      data: { investor_notifications_enabled: false, investor_email_whitelist: [] },
    } as { data?: Record<string, unknown> });
    vi.mocked(api.getDepositOptions).mockResolvedValue({ data: [] } as { data?: unknown[] });
  });

  it('renders tabs and shows Usuarios by default', async () => {
    render(
      <MemoryRouter>
        <AdminsHubPage />
      </MemoryRouter>,
    );

    expect(screen.getByRole('button', { name: 'Usuarios' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Configuración' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Métodos de Depósito' })).toBeInTheDocument();

    await waitFor(() => expect(api.getAdminAdmins).toHaveBeenCalled());
  });

  it('switches to Configuración tab', async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter>
        <AdminsHubPage />
      </MemoryRouter>,
    );

    await user.click(screen.getByRole('button', { name: 'Configuración' }));
    await waitFor(() => expect(api.getAdminSettings).toHaveBeenCalled());
  });
});
