import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DepositOptionsPage } from './DepositOptionsPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getDepositOptions: vi.fn(),
    createDepositOption: vi.fn(),
    updateDepositOption: vi.fn(),
    deleteDepositOption: vi.fn(),
    toggleDepositOption: vi.fn(),
  },
}));

global.alert = vi.fn();

describe('DepositOptionsPage', () => {
  const mockOptions = {
    data: [
      {
        id: '1',
        category: 'BANK_ARS',
        label: 'Banco Galicia',
        currency: 'ARS',
        details: { bank_name: 'Galicia', holder: 'Winbit SRL', cbu_cvu: '0070000' },
        active: true,
        position: 1,
        createdAt: '2024-01-01T10:00:00Z',
        updatedAt: '2024-01-01T10:00:00Z',
      },
      {
        id: '2',
        category: 'CRYPTO',
        label: 'USDT TRC20',
        currency: 'USDT',
        details: { address: 'TF7j33wo', network: 'TRC20' },
        active: false,
        position: 2,
        createdAt: '2024-01-02T10:00:00Z',
        updatedAt: '2024-01-02T10:00:00Z',
      },
    ],
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Listar opciones', () => {
    it('renders loading state initially', async () => {
      vi.mocked(api.getDepositOptions).mockImplementation(() => new Promise(() => {}));

      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(screen.getByText(/Cargando opciones/)).toBeInTheDocument();
      });
    });

    it('renders options list after loading', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue(mockOptions);

      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(api.getDepositOptions).toHaveBeenCalled();
      });

      expect(screen.getAllByText('Banco Galicia').length).toBeGreaterThan(0);
      expect(screen.getAllByText('USDT TRC20').length).toBeGreaterThan(0);
    });

    it('renders error message when fetch fails', async () => {
      vi.mocked(api.getDepositOptions).mockRejectedValue(new Error('Network error'));

      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(screen.getByText('Network error')).toBeInTheDocument();
      });
    });

    it('renders empty state when no options', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue({ data: [] });

      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(screen.getByText(/No hay opciones de depósito/)).toBeInTheDocument();
      });
    });

    it('shows active/inactive badges', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue(mockOptions);

      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(api.getDepositOptions).toHaveBeenCalled();
      });

      expect(screen.getAllByText('Activo').length).toBeGreaterThan(0);
      expect(screen.getAllByText('Inactivo').length).toBeGreaterThan(0);
    });
  });

  describe('Crear opción', () => {
    it('shows form when "+ Nueva opción" button is clicked', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue(mockOptions);

      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(api.getDepositOptions).toHaveBeenCalled();
      });

      const addButton = await screen.findByRole('button', { name: /Nueva opción/i });
      fireEvent.click(addButton);

      expect(screen.getByText('Nueva opción de depósito')).toBeInTheDocument();
    });

    it('creates new deposit option successfully', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue(mockOptions);
      vi.mocked(api.createDepositOption).mockResolvedValue({ data: { id: '3' } });

      const user = userEvent.setup();
      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(api.getDepositOptions).toHaveBeenCalled();
      });

      const addButton = await screen.findByRole('button', { name: /Nueva opción/i });
      await user.click(addButton);

      const labelInput = screen.getByPlaceholderText('Ej: Banco Galicia - Pesos');
      await user.type(labelInput, 'Lemon Cash');

      const submitButton = screen.getByRole('button', { name: /Crear/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(api.createDepositOption).toHaveBeenCalled();
      });
    });
  });

  describe('Toggle active', () => {
    it('toggles option active state', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue(mockOptions);
      vi.mocked(api.toggleDepositOption).mockResolvedValue({ data: { ...mockOptions.data[0], active: false } });

      const user = userEvent.setup();
      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(api.getDepositOptions).toHaveBeenCalled();
      });

      const activeButtons = screen.getAllByText('Activo');
      await user.click(activeButtons[0]);

      await waitFor(() => {
        expect(api.toggleDepositOption).toHaveBeenCalledWith('1');
      });
    });
  });

  describe('Eliminar opción', () => {
    it('deletes option after confirmation', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue(mockOptions);
      vi.mocked(api.deleteDepositOption).mockResolvedValue({});

      const user = userEvent.setup();
      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(api.getDepositOptions).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      await waitFor(() => {
        expect(screen.getByText('Eliminar opción de depósito')).toBeInTheDocument();
      });

      const confirmButtons = screen.getAllByRole('button', { name: 'Eliminar' });
      await user.click(confirmButtons[confirmButtons.length - 1]);

      await waitFor(() => {
        expect(api.deleteDepositOption).toHaveBeenCalledWith('1');
      });
    });
  });

  describe('Editar opción', () => {
    it('shows edit form when edit button is clicked', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue(mockOptions);

      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(api.getDepositOptions).toHaveBeenCalled();
      });

      const editButtons = screen.getAllByTitle('Editar');
      fireEvent.click(editButtons[0]);

      await waitFor(() => {
        expect(screen.getAllByText('Editar opción').length).toBeGreaterThan(0);
      });
    });

    it('updates option successfully', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue(mockOptions);
      vi.mocked(api.updateDepositOption).mockResolvedValue({});

      const user = userEvent.setup();
      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(api.getDepositOptions).toHaveBeenCalled();
      });

      const editButtons = screen.getAllByTitle('Editar');
      await user.click(editButtons[0]);

      const saveButtons = screen.getAllByRole('button', { name: /Guardar/i });
      await user.click(saveButtons[0]);

      await waitFor(() => {
        expect(api.updateDepositOption).toHaveBeenCalledWith('1', expect.objectContaining({
          category: 'BANK_ARS',
          label: 'Banco Galicia',
        }));
      });
    });
  });

  describe('Form interactions', () => {
    it('cancels create form without submitting', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue(mockOptions);

      const user = userEvent.setup();
      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(api.getDepositOptions).toHaveBeenCalled();
      });

      const addButton = await screen.findByRole('button', { name: /Nueva opción/i });
      await user.click(addButton);

      expect(screen.getByText('Nueva opción de depósito')).toBeInTheDocument();

      const cancelButtons = screen.getAllByRole('button', { name: /Cancelar/i });
      await user.click(cancelButtons[0]);

      expect(screen.queryByText('Nueva opción de depósito')).not.toBeInTheDocument();
      expect(api.createDepositOption).not.toHaveBeenCalled();
    });

    it('shows dynamic fields when category changes', async () => {
      vi.mocked(api.getDepositOptions).mockResolvedValue({ data: [] });

      const user = userEvent.setup();
      render(<DepositOptionsPage />);

      await waitFor(() => {
        expect(api.getDepositOptions).toHaveBeenCalled();
      });

      const addButton = await screen.findByRole('button', { name: /Nueva opción/i });
      await user.click(addButton);

      // Default is CASH_ARS - select BANK_ARS
      const categorySelect = screen.getAllByRole('combobox')[0];
      await user.selectOptions(categorySelect, 'BANK_ARS');

      expect(screen.getByPlaceholderText('Ej: Banco Galicia')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('Ej: Winbit SRL')).toBeInTheDocument();

      // Switch to CRYPTO
      await user.selectOptions(categorySelect, 'CRYPTO');

      expect(screen.getByPlaceholderText(/TF7j33wo/)).toBeInTheDocument();
      expect(screen.getByPlaceholderText(/TRC20, BEP20/)).toBeInTheDocument();
    });
  });
});
