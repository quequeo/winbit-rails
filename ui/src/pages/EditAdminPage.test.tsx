import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { EditAdminPage } from './EditAdminPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getAdminAdmins: vi.fn(),
    updateAdmin: vi.fn(),
  },
}));

const renderRoute = () =>
  render(
    <MemoryRouter initialEntries={['/admins/1/edit']}>
      <Routes>
        <Route path="/admins/:id/edit" element={<EditAdminPage />} />
        <Route path="/admins" element={<div>Admins</div>} />
      </Routes>
    </MemoryRouter>,
  );

describe('EditAdminPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('loads admin and updates values', async () => {
    vi.mocked(api.getAdminAdmins).mockResolvedValue({
      data: [
        {
          id: '1',
          email: 'admin1@test.com',
          name: 'Admin One',
          role: 'ADMIN',
          notify_deposit_created: true,
          notify_withdrawal_created: false,
        },
      ],
    });
    vi.mocked(api.updateAdmin).mockResolvedValue({});

    const user = userEvent.setup();
    renderRoute();

    await waitFor(() => expect(screen.getByDisplayValue('admin1@test.com')).toBeInTheDocument());
    const textInputs = screen.getAllByRole('textbox');
    const nameInput = textInputs[1] as HTMLInputElement;
    await user.clear(nameInput);
    await user.type(nameInput, 'Updated Name');

    await user.click(screen.getByRole('button', { name: /Guardar cambios/i }));

    await waitFor(() => {
      expect(api.updateAdmin).toHaveBeenCalledWith(
        '1',
        expect.objectContaining({
          email: 'admin1@test.com',
          name: 'Updated Name',
          role: 'ADMIN',
          notify_deposit_created: true,
          notify_withdrawal_created: false,
        }),
      );
    });
  });
});
