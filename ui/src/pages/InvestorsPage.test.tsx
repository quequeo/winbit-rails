import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { InvestorsPage } from './InvestorsPage';
import { api } from '../lib/api';

// Mock del módulo api
vi.mock('../lib/api', () => ({
  api: {
    getAdminInvestors: vi.fn(),
    createInvestor: vi.fn(),
    updateInvestor: vi.fn(),
    deleteInvestor: vi.fn(),
  },
}));

// Mock de window.confirm
global.confirm = vi.fn(() => true);

describe('InvestorsPage', () => {
  const mockInvestors = {
    data: [
      {
        id: '1',
        email: 'investor1@test.com',
        name: 'Investor One',
        status: 'ACTIVE',
        portfolio: { currentBalance: 1000 },
      },
      {
        id: '2',
        email: 'investor2@test.com',
        name: 'Investor Two',
        status: 'INACTIVE',
        portfolio: { currentBalance: 500 },
      },
    ],
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Listar inversores', () => {
    it('renders loading state initially', () => {
      vi.mocked(api.getAdminInvestors).mockImplementation(() => new Promise(() => {}));

      render(<InvestorsPage />);

      expect(screen.getByText('Cargando...')).toBeInTheDocument();
    });

    it('renders investors list after loading', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);

      render(<InvestorsPage />);

      await waitFor(() => {
        expect(screen.getAllByText('Investor One').length).toBeGreaterThan(0);
      });
      
      expect(screen.getAllByText('Investor Two').length).toBeGreaterThan(0);
    });

    it('renders error message when fetch fails', async () => {
      vi.mocked(api.getAdminInvestors).mockRejectedValue(new Error('Network error'));

      render(<InvestorsPage />);

      await waitFor(() => {
        expect(screen.getByText('Network error')).toBeInTheDocument();
      });
    });

    it('calls API with sort parameters when sorting column headers are clicked', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);

      render(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      // Find the "Nombre" column header button in the table
      const nameButtons = screen.getAllByText(/Nombre/i);
      const nameButton = nameButtons.find(el => el.closest('button'))?.closest('button');
      
      expect(nameButton).toBeDefined();
      fireEvent.click(nameButton!);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalledWith({
          sort_by: 'name',
          sort_order: 'desc',
        });
      });

      // Click again to reverse order
      fireEvent.click(nameButton!);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalledWith({
          sort_by: 'name',
          sort_order: 'asc',
        });
      });
    });
  });

  describe('Crear inversor', () => {
    it('shows form when "Agregar Inversor" button is clicked', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);

      render(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      const addButton = screen.getByRole('button', { name: /Agregar Inversor/i });
      fireEvent.click(addButton);

      expect(screen.getByText('Nuevo Inversor')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('inversor@ejemplo.com')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('María González')).toBeInTheDocument();
    });

    it('creates new investor successfully', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      vi.mocked(api.createInvestor).mockResolvedValue({ data: { id: '3' } });

      const user = userEvent.setup();
      render(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      // Open form
      const addButton = screen.getByRole('button', { name: /Agregar Inversor/i });
      await user.click(addButton);

      // Fill form
      const emailInput = screen.getByPlaceholderText('inversor@ejemplo.com');
      const nameInput = screen.getByPlaceholderText('María González');

      await user.type(emailInput, 'new@test.com');
      await user.type(nameInput, 'New Investor');

      // Submit
      const submitButton = screen.getByRole('button', { name: /Crear Inversor/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(api.createInvestor).toHaveBeenCalledWith({
          email: 'new@test.com',
          name: 'New Investor',
        });
      });

      // Should reload investors
      expect(api.getAdminInvestors).toHaveBeenCalledTimes(2);
    });

    it('shows alert on create error', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      vi.mocked(api.createInvestor).mockRejectedValue(new Error('Email already exists'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const user = userEvent.setup();

      render(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      // Open form and submit
      const addButton = screen.getByRole('button', { name: /Agregar Inversor/i });
      await user.click(addButton);

      const emailInput = screen.getByPlaceholderText('inversor@ejemplo.com');
      const nameInput = screen.getByPlaceholderText('María González');

      await user.type(emailInput, 'duplicate@test.com');
      await user.type(nameInput, 'Duplicate');

      const submitButton = screen.getByRole('button', { name: /Crear Inversor/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Email already exists');
      });

      alertSpy.mockRestore();
    });
  });

  describe('Editar inversor', () => {
    it('shows inline edit form when edit button is clicked', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);

      render(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      // Click edit button (pencil icon)
      const editButtons = screen.getAllByTitle('Editar');
      fireEvent.click(editButtons[0]);

      // Should show input fields with current values
      await waitFor(() => {
        const emailInputs = screen.getAllByDisplayValue('investor1@test.com');
        expect(emailInputs.length).toBeGreaterThan(0);
      });
    });

    it('updates investor successfully', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      vi.mocked(api.updateInvestor).mockResolvedValue({});

      const user = userEvent.setup();
      render(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      // Click edit
      const editButtons = screen.getAllByTitle('Editar');
      await user.click(editButtons[0]);

      // Modify fields
      const emailInputs = screen.getAllByDisplayValue('investor1@test.com');
      await user.clear(emailInputs[0]);
      await user.type(emailInputs[0], 'updated@test.com');

      // Save
      const saveButtons = screen.getAllByRole('button', { name: /Guardar/i });
      await user.click(saveButtons[0]);

      await waitFor(() => {
        expect(api.updateInvestor).toHaveBeenCalledWith('1', {
          email: 'updated@test.com',
          name: 'Investor One',
        });
      });

      // Should reload investors
      expect(api.getAdminInvestors).toHaveBeenCalledTimes(2);
    });

    it('shows alert on update error', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      vi.mocked(api.updateInvestor).mockRejectedValue(new Error('Update failed'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const user = userEvent.setup();

      render(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
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

  describe('Eliminar inversor', () => {
    it('deletes investor after confirmation', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      vi.mocked(api.deleteInvestor).mockResolvedValue({});
      const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);

      const user = userEvent.setup();
      render(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      // Click delete button (trash icon)
      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      await waitFor(() => {
        expect(confirmSpy).toHaveBeenCalledWith('¿Estás seguro de eliminar a Investor One?');
        expect(api.deleteInvestor).toHaveBeenCalledWith('1');
      });

      // Should reload investors
      expect(api.getAdminInvestors).toHaveBeenCalledTimes(2);

      confirmSpy.mockRestore();
    });

    it('does not delete when confirmation is cancelled', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(false);

      const user = userEvent.setup();
      render(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      expect(confirmSpy).toHaveBeenCalled();
      expect(api.deleteInvestor).not.toHaveBeenCalled();

      confirmSpy.mockRestore();
    });

    it('shows alert on delete error', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      vi.mocked(api.deleteInvestor).mockRejectedValue(new Error('Delete failed'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);
      const user = userEvent.setup();

      render(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Delete failed');
      });

      alertSpy.mockRestore();
      confirmSpy.mockRestore();
    });
  });
});
