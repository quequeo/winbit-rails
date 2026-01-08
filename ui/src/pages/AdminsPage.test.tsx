import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { AdminsPage } from './AdminsPage';
import { api } from '../lib/api';

// Mock del módulo api
vi.mock('../lib/api', () => ({
  api: {
    getAdminAdmins: vi.fn(),
    getAdminSession: vi.fn(),
    createAdmin: vi.fn(),
    updateAdmin: vi.fn(),
    deleteAdmin: vi.fn(),
  },
}));

// Mock de window.confirm y window.alert
global.confirm = vi.fn(() => true);
global.alert = vi.fn();

describe('AdminsPage', () => {
  const mockAdmins = {
    data: [
      {
        id: '1',
        email: 'admin1@test.com',
        name: 'Admin One',
        role: 'ADMIN',
        createdAt: '2024-01-01T10:00:00Z',
      },
      {
        id: '2',
        email: 'admin2@test.com',
        name: 'Admin Two',
        role: 'SUPERADMIN',
        createdAt: '2024-01-02T10:00:00Z',
      },
    ],
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getAdminSession).mockResolvedValue({ data: { email: 'admin@test.com' } });
  });

  describe('Listar admins', () => {
    it('renders loading state initially', () => {
      vi.mocked(api.getAdminAdmins).mockImplementation(() => new Promise(() => {}));

      render(<AdminsPage />);

      expect(screen.getByText('Cargando...')).toBeInTheDocument();
    });

    it('renders admins list after loading', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);

      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      expect(screen.getAllByText('Admin One').length).toBeGreaterThan(0);
      expect(screen.getAllByText('Admin Two').length).toBeGreaterThan(0);
    });

    it('renders error message when fetch fails', async () => {
      vi.mocked(api.getAdminAdmins).mockRejectedValue(new Error('Network error'));

      render(<AdminsPage />);

      await waitFor(() => {
        expect(screen.getByText('Network error')).toBeInTheDocument();
      });
    });
  });

  describe('Crear admin', () => {
    it('shows form when "+ Agregar Admin" button is clicked', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);

      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const addButton = screen.getByRole('button', { name: /Agregar Admin/i });
      fireEvent.click(addButton);

      expect(screen.getByText('Nuevo Admin')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('admin@ejemplo.com')).toBeInTheDocument();
    });

    it('creates new admin successfully', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.createAdmin).mockResolvedValue({ data: { id: '3' } });

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      // Open form
      const addButton = screen.getByRole('button', { name: /Agregar Admin/i });
      await user.click(addButton);

      // Fill form
      const emailInput = screen.getByPlaceholderText('admin@ejemplo.com');
      await user.type(emailInput, 'new@test.com');

      const nameInput = screen.getByPlaceholderText('Juan Pérez');
      await user.type(nameInput, 'New Admin');

      const roleSelect = screen.getByLabelText(/Rol \*/i);
      await user.selectOptions(roleSelect, 'ADMIN');

      // Submit
      const submitButton = screen.getByRole('button', { name: /Crear Admin/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(api.createAdmin).toHaveBeenCalledWith({
          email: 'new@test.com',
          name: 'New Admin',
          role: 'ADMIN',
        });
      });

      // Should reload admins
      expect(api.getAdminAdmins).toHaveBeenCalledTimes(2);
    });

    it('creates admin without name', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.createAdmin).mockResolvedValue({ data: { id: '3' } });

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const addButton = screen.getByRole('button', { name: /Agregar Admin/i });
      await user.click(addButton);

      const emailInput = screen.getByPlaceholderText('admin@ejemplo.com');
      await user.type(emailInput, 'new@test.com');

      const roleSelect = screen.getByLabelText(/Rol \*/i);
      await user.selectOptions(roleSelect, 'SUPERADMIN');

      const submitButton = screen.getByRole('button', { name: /Crear Admin/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(api.createAdmin).toHaveBeenCalledWith({
          email: 'new@test.com',
          name: '',
          role: 'SUPERADMIN',
        });
      });
    });

    it('shows alert on create error', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.createAdmin).mockRejectedValue(new Error('Email already exists'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const user = userEvent.setup();

      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const addButton = screen.getByRole('button', { name: /Agregar Admin/i });
      await user.click(addButton);

      const emailInput = screen.getByPlaceholderText('admin@ejemplo.com');
      await user.type(emailInput, 'duplicate@test.com');

      const roleSelect = screen.getByLabelText(/Rol \*/i);
      await user.selectOptions(roleSelect, 'ADMIN');

      const submitButton = screen.getByRole('button', { name: /Crear Admin/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Email already exists');
      });

      alertSpy.mockRestore();
    });
  });

  describe('Editar admin', () => {
    it('shows inline edit form when edit button is clicked', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);

      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const editButtons = screen.getAllByTitle('Editar');
      fireEvent.click(editButtons[0]);

      await waitFor(() => {
        const emailInputs = screen.getAllByDisplayValue('admin1@test.com');
        expect(emailInputs.length).toBeGreaterThan(0);
      });
    });

    it('updates admin successfully', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.updateAdmin).mockResolvedValue({});

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const editButtons = screen.getAllByTitle('Editar');
      await user.click(editButtons[0]);

      // Modify email
      const emailInputs = screen.getAllByDisplayValue('admin1@test.com');
      await user.clear(emailInputs[0]);
      await user.type(emailInputs[0], 'updated@test.com');

      // Save
      const saveButtons = screen.getAllByRole('button', { name: /Guardar/i });
      await user.click(saveButtons[0]);

      await waitFor(() => {
        expect(api.updateAdmin).toHaveBeenCalledWith('1', expect.objectContaining({
          email: 'updated@test.com',
        }));
      });

      // Should reload admins
      expect(api.getAdminAdmins).toHaveBeenCalledTimes(2);
    });

    it('shows alert on update error', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.updateAdmin).mockRejectedValue(new Error('Update failed'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const user = userEvent.setup();

      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const editButtons = screen.getAllByTitle('Editar');
      await user.click(editButtons[0]);

      const saveButtons = screen.getAllByRole('button', { name: /Guardar/i });
      await user.click(saveButtons[0]);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Update failed');
      });

      alertSpy.mockRestore();
    });
  });

  describe('Eliminar admin', () => {
    it('deletes admin after confirmation', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.deleteAdmin).mockResolvedValue({});
      const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      await waitFor(() => {
        expect(confirmSpy).toHaveBeenCalledWith('¿Estás seguro de eliminar a admin1@test.com?');
        expect(api.deleteAdmin).toHaveBeenCalledWith('1');
      });

      // Should reload admins
      expect(api.getAdminAdmins).toHaveBeenCalledTimes(2);

      confirmSpy.mockRestore();
    });

    it('does not delete when confirmation is cancelled', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(false);

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      expect(confirmSpy).toHaveBeenCalled();
      expect(api.deleteAdmin).not.toHaveBeenCalled();

      confirmSpy.mockRestore();
    });

    it('shows alert on delete error', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.deleteAdmin).mockRejectedValue(new Error('Cannot delete yourself'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);
      const user = userEvent.setup();

      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Cannot delete yourself');
      });

      alertSpy.mockRestore();
      confirmSpy.mockRestore();
    });
  });
});
