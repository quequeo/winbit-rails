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
    it('renders loading state initially', async () => {
      vi.mocked(api.getAdminAdmins).mockImplementation(() => new Promise(() => {}));

      render(<AdminsPage />);

      await waitFor(() => {
        expect(screen.getByText('Cargando...')).toBeInTheDocument();
      });
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

      const addButton = await screen.findByRole('button', { name: /Agregar Admin/i });
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
      const addButton = await screen.findByRole('button', { name: /Agregar Admin/i });
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

      const addButton = await screen.findByRole('button', { name: /Agregar Admin/i });
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

      const addButton = await screen.findByRole('button', { name: /Agregar Admin/i });
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

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      // Modal should appear - click confirm button
      await waitFor(() => {
        expect(screen.getByText('Eliminar Administrador')).toBeInTheDocument();
      });

      // Get all "Eliminar" buttons - the modal's will be the last one
      const confirmButtons = screen.getAllByRole('button', { name: 'Eliminar' });
      await user.click(confirmButtons[confirmButtons.length - 1]);

      await waitFor(() => {
        expect(api.deleteAdmin).toHaveBeenCalledWith('1');
      });

      // Should reload admins
      expect(api.getAdminAdmins).toHaveBeenCalledTimes(2);
    });

    it('does not delete when confirmation is cancelled', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      // Modal should appear - click cancel button
      await waitFor(() => {
        expect(screen.getByText('Eliminar Administrador')).toBeInTheDocument();
      });

      const cancelButton = screen.getByRole('button', { name: 'Cancelar' });
      await user.click(cancelButton);

      expect(api.deleteAdmin).not.toHaveBeenCalled();
    });

    it('shows alert on delete error', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.deleteAdmin).mockRejectedValue(new Error('Cannot delete yourself'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const user = userEvent.setup();

      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      // Modal should appear - click confirm button
      await waitFor(() => {
        expect(screen.getByText('Eliminar Administrador')).toBeInTheDocument();
      });

      // Get all "Eliminar" buttons - the modal's will be the last one
      const confirmButtons = screen.getAllByRole('button', { name: 'Eliminar' });
      await user.click(confirmButtons[confirmButtons.length - 1]);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Cannot delete yourself');
      });

      alertSpy.mockRestore();
    });

    it('prevents deleting own account by disabling button', async () => {
      const mockAdminsWithLoggedUser = {
        data: [
          {
            id: '1',
            email: 'admin@test.com', // Same as logged in user
            name: 'Logged Admin',
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

      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdminsWithLoggedUser);

      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      // Wait for the data to render before checking buttons
      await waitFor(() => {
        expect(screen.getAllByText('Logged Admin').length).toBeGreaterThan(0);
      });

      // Find all delete buttons with title
      const allButtons = screen.getAllByRole('button');
      const deleteButtons = allButtons.filter(
        (btn) => btn.title && btn.title.toLowerCase().includes('eliminar')
      );

      // The first delete button should be disabled (own account)
      const ownAccountButton = deleteButtons.find(
        (btn) => btn.title?.includes('No puedes eliminar')
      );
      expect(ownAccountButton).toBeInTheDocument();
      expect(ownAccountButton).toBeDisabled();

      // The second delete button should NOT be disabled (other account)
      const otherAccountButton = deleteButtons.find(
        (btn) => btn.title === 'Eliminar'
      );
      expect(otherAccountButton).toBeInTheDocument();
      expect(otherAccountButton).not.toBeDisabled();
    });
  });

  describe('Toggle notifications', () => {
    it('toggles deposit notification successfully', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.updateAdmin).mockResolvedValue({});

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      // Find checkbox for deposit notifications
      const depositCheckboxes = screen.getAllByLabelText(/Depósito recibido/i);
      await user.click(depositCheckboxes[0]);

      await waitFor(() => {
        expect(api.updateAdmin).toHaveBeenCalledWith('1', expect.objectContaining({
          email: 'admin1@test.com',
          name: 'Admin One',
          role: 'ADMIN',
          notify_deposit_created: false,
        }));
      });

      expect(api.getAdminAdmins).toHaveBeenCalledTimes(2);
    });

    it('toggles withdrawal notification successfully', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.updateAdmin).mockResolvedValue({});

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      // Find checkbox for withdrawal notifications
      const withdrawalCheckboxes = screen.getAllByLabelText(/Retiro solicitado/i);
      await user.click(withdrawalCheckboxes[0]);

      await waitFor(() => {
        expect(api.updateAdmin).toHaveBeenCalledWith('1', expect.objectContaining({
          email: 'admin1@test.com',
          name: 'Admin One',
          role: 'ADMIN',
          notify_withdrawal_created: false,
        }));
      });

      expect(api.getAdminAdmins).toHaveBeenCalledTimes(2);
    });

    it('shows alert on notification toggle error', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.updateAdmin).mockRejectedValue(new Error('Update failed'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const user = userEvent.setup();

      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      const depositCheckboxes = screen.getAllByLabelText(/Depósito recibido/i);
      await user.click(depositCheckboxes[0]);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Update failed');
      });

      alertSpy.mockRestore();
    });
  });

  describe('Form interactions', () => {
    it('cancels create form without submitting', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      // Open form
      const addButton = await screen.findByRole('button', { name: /Agregar Admin/i });
      await user.click(addButton);

      expect(screen.getByText('Nuevo Admin')).toBeInTheDocument();

      // Cancel using the cancel button in the form
      const cancelButtons = screen.getAllByRole('button', { name: /Cancelar/i });
      await user.click(cancelButtons[0]);

      expect(screen.queryByText('Nuevo Admin')).not.toBeInTheDocument();
      expect(api.createAdmin).not.toHaveBeenCalled();
    });

    it('cancels edit form without submitting', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      // Start editing
      const editButtons = screen.getAllByTitle('Editar');
      await user.click(editButtons[0]);

      await waitFor(() => {
        const emailInputs = screen.getAllByDisplayValue('admin1@test.com');
        expect(emailInputs.length).toBeGreaterThan(0);
      });

      // Cancel edit
      const cancelButtons = screen.getAllByRole('button', { name: /Cancelar/i });
      await user.click(cancelButtons[0]);

      await waitFor(() => {
        const emailInputs = screen.queryAllByDisplayValue('admin1@test.com');
        expect(emailInputs.length).toBe(0);
      });

      expect(api.updateAdmin).not.toHaveBeenCalled();
    });

    it('updates all form fields in create form', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);
      vi.mocked(api.createAdmin).mockResolvedValue({ data: { id: '3' } });

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      // Open form
      const addButton = await screen.findByRole('button', { name: /Agregar Admin/i });
      await user.click(addButton);

      // Fill all fields
      const emailInput = screen.getByPlaceholderText('admin@ejemplo.com');
      await user.type(emailInput, 'test@example.com');

      const nameInput = screen.getByPlaceholderText('Juan Pérez');
      await user.type(nameInput, 'Test User');

      const roleSelect = screen.getByLabelText(/Rol \*/i);
      await user.selectOptions(roleSelect, 'SUPERADMIN');

      // Submit
      const submitButton = screen.getByRole('button', { name: /Crear Admin/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(api.createAdmin).toHaveBeenCalledWith({
          email: 'test@example.com',
          name: 'Test User',
          role: 'SUPERADMIN',
        });
      });
    });

    it('updates notification checkboxes in edit form', async () => {
      const mockAdminsWithNotifications = {
        data: [
          {
            id: '1',
            email: 'admin1@test.com',
            name: 'Admin One',
            role: 'ADMIN',
            createdAt: '2024-01-01T10:00:00Z',
            notify_deposit_created: true,
            notify_withdrawal_created: true,
          },
        ],
      };

      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdminsWithNotifications);
      vi.mocked(api.updateAdmin).mockResolvedValue({});

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      // Start editing
      const editButtons = screen.getAllByTitle('Editar');
      await user.click(editButtons[0]);

      await waitFor(() => {
        expect(screen.getAllByDisplayValue('admin1@test.com').length).toBeGreaterThan(0);
      });

      // In edit mode, find the checkboxes
      const allDepositCheckboxes = screen.getAllByLabelText(/Depósito recibido/i);
      const allWithdrawalCheckboxes = screen.getAllByLabelText(/Retiro solicitado/i);

      // Toggle both notifications off
      await user.click(allDepositCheckboxes[allDepositCheckboxes.length - 1]);
      await user.click(allWithdrawalCheckboxes[allWithdrawalCheckboxes.length - 1]);

      // Save changes
      const saveButtons = screen.getAllByRole('button', { name: /Guardar/i });
      await user.click(saveButtons[0]);

      await waitFor(() => {
        expect(api.updateAdmin).toHaveBeenCalledWith('1', expect.objectContaining({
          email: 'admin1@test.com',
          name: 'Admin One',
          role: 'ADMIN',
          notify_deposit_created: false,
          notify_withdrawal_created: false,
        }));
      });
    });

    it('can toggle form visibility multiple times', async () => {
      vi.mocked(api.getAdminAdmins).mockResolvedValue(mockAdmins);

      const user = userEvent.setup();
      render(<AdminsPage />);

      await waitFor(() => {
        expect(api.getAdminAdmins).toHaveBeenCalled();
      });

      // Open form
      const addButton = await screen.findByRole('button', { name: /Agregar Admin/i });
      await user.click(addButton);
      expect(screen.getByText('Nuevo Admin')).toBeInTheDocument();

      // Close form by clicking cancel button in form
      const cancelButtons = screen.getAllByRole('button', { name: /Cancelar/i });
      await user.click(cancelButtons[0]); // First cancel button is in the form
      expect(screen.queryByText('Nuevo Admin')).not.toBeInTheDocument();

      // Re-open form
      const addButtonAgain = await screen.findByRole('button', { name: /Agregar Admin/i });
      await user.click(addButtonAgain);
      expect(screen.getByText('Nuevo Admin')).toBeInTheDocument();
    });
  });
});
