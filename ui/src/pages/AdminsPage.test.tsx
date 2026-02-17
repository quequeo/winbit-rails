import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { AdminsPage } from './AdminsPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getAdminAdmins: vi.fn(),
    getAdminSession: vi.fn(),
    createAdmin: vi.fn(),
    deleteAdmin: vi.fn(),
  },
}));

const renderWithRouter = (ui: React.ReactElement) => render(<MemoryRouter>{ui}</MemoryRouter>);

describe('AdminsPage', () => {
  const mockAdmins = {
    data: [
      {
        id: '1',
        email: 'admin1@test.com',
        name: 'Admin One',
        role: 'ADMIN',
        notify_deposit_created: true,
        notify_withdrawal_created: false,
      },
      {
        id: '2',
        email: 'admin2@test.com',
        name: 'Admin Two',
        role: 'SUPERADMIN',
        notify_deposit_created: true,
        notify_withdrawal_created: true,
      },
    ],
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getAdminSession).mockResolvedValue({ data: { email: 'admin@test.com' } });
  });

  it('renders admins and notification counters', async () => {
    vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);

    renderWithRouter(<AdminsPage />);

    await waitFor(() => {
      expect(screen.getAllByText('admin1@test.com').length).toBeGreaterThan(0);
    });

    expect(screen.getByText('1 / 2 activas')).toBeInTheDocument();
    expect(screen.getByText('2 / 2 activas')).toBeInTheDocument();
  });

  it('creates admin from the create form', async () => {
    vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
    vi.mocked(api.createAdmin).mockResolvedValue({ data: { id: '3' } });

    const user = userEvent.setup();
    renderWithRouter(<AdminsPage />);

    await waitFor(() => expect(api.getAdminAdmins).toHaveBeenCalledTimes(1));

    await user.click(screen.getByRole('button', { name: /\+ Agregar Admin/i }));
    await user.type(screen.getByPlaceholderText('admin@ejemplo.com'), 'new@test.com');
    await user.type(screen.getByPlaceholderText('Juan Pérez'), 'New Admin');
    await user.click(screen.getByRole('button', { name: /Crear Admin/i }));

    await waitFor(() => {
      expect(api.createAdmin).toHaveBeenCalledWith({
        email: 'new@test.com',
        name: 'New Admin',
        role: 'ADMIN',
      });
    });
  });

  it('deletes admin after confirmation', async () => {
    vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
    vi.mocked(api.deleteAdmin).mockResolvedValue({});

    const user = userEvent.setup();
    renderWithRouter(<AdminsPage />);

    await waitFor(() => expect(api.getAdminAdmins).toHaveBeenCalledTimes(1));

    const deleteButtons = screen.getAllByTitle('Eliminar');
    await user.click(deleteButtons[0]);
    await waitFor(() => expect(screen.getByText('Eliminar Administrador')).toBeInTheDocument());

    const confirmButtons = screen.getAllByRole('button', { name: 'Eliminar' });
    await user.click(confirmButtons[confirmButtons.length - 1]);

    await waitFor(() => expect(api.deleteAdmin).toHaveBeenCalledWith('1'));
  });
});
