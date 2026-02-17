import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { InvestorsPage } from './InvestorsPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getAdminInvestors: vi.fn(),
    createInvestor: vi.fn(),
    deleteInvestor: vi.fn(),
    toggleInvestorStatus: vi.fn(),
  },
}));

global.confirm = vi.fn(() => true);

const renderWithRouter = (ui: React.ReactElement) =>
  render(<MemoryRouter>{ui}</MemoryRouter>);

describe('InvestorsPage', () => {
  const mockInvestors = {
    data: [
      {
        id: '1',
        email: 'investor1@test.com',
        name: 'Investor One',
        status: 'ACTIVE',
        tradingFeeFrequency: 'QUARTERLY',
        hasPassword: false,
        portfolio: { currentBalance: 1000, totalInvested: 800 },
      },
      {
        id: '2',
        email: 'investor2@test.com',
        name: 'Investor Two',
        status: 'INACTIVE',
        tradingFeeFrequency: 'ANNUAL',
        hasPassword: true,
        portfolio: { currentBalance: 500, totalInvested: 400 },
      },
    ],
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('Listar inversores', () => {
    it('renders loading state initially', () => {
      vi.mocked(api.getAdminInvestors).mockImplementation(() => new Promise(() => {}));

      renderWithRouter(<InvestorsPage />);

      expect(screen.getByText('Cargando...')).toBeInTheDocument();
    });

    it('renders investors list after loading', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);

      renderWithRouter(<InvestorsPage />);

      await waitFor(() => {
        expect(screen.getAllByText('Investor One').length).toBeGreaterThan(0);
      });

      expect(screen.getAllByText('Investor Two').length).toBeGreaterThan(0);
    });

    it('renders error message when fetch fails', async () => {
      vi.mocked(api.getAdminInvestors).mockRejectedValue(new Error('Network error'));

      renderWithRouter(<InvestorsPage />);

      await waitFor(() => {
        expect(screen.getByText('Network error')).toBeInTheDocument();
      });
    });

    it('fetches investors on mount', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);

      renderWithRouter(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalledWith({});
      });
    });
  });

  describe('Crear inversor', () => {
    it('shows form when "Agregar Inversor" button is clicked', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);

      renderWithRouter(<InvestorsPage />);

      const addButton = await screen.findByRole('button', { name: /\+ Agregar Inversor/i });
      fireEvent.click(addButton);

      expect(screen.getByText('Nuevo Inversor')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('inversor@ejemplo.com')).toBeInTheDocument();
      expect(screen.getByPlaceholderText('María González')).toBeInTheDocument();
    });

    it('creates new investor successfully', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      vi.mocked(api.createInvestor).mockResolvedValue({ data: { id: '3' } });

      const user = userEvent.setup();
      renderWithRouter(<InvestorsPage />);

      const addButton = await screen.findByRole('button', { name: /\+ Agregar Inversor/i });
      await user.click(addButton);

      const emailInput = screen.getByPlaceholderText('inversor@ejemplo.com');
      const nameInput = screen.getByPlaceholderText('María González');

      await user.type(emailInput, 'new@test.com');
      await user.type(nameInput, 'New Investor');

      const submitButton = screen.getByRole('button', { name: /Crear Inversor/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(api.createInvestor).toHaveBeenCalledWith({
          email: 'new@test.com',
          name: 'New Investor',
        });
      });

      expect(api.getAdminInvestors).toHaveBeenCalledTimes(2);
    });

    it('shows alert on create error', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      vi.mocked(api.createInvestor).mockRejectedValue(new Error('Email already exists'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const user = userEvent.setup();

      renderWithRouter(<InvestorsPage />);

      const addButton = await screen.findByRole('button', { name: /\+ Agregar Inversor/i });
      await user.click(addButton);

      await user.type(screen.getByPlaceholderText('inversor@ejemplo.com'), 'dup@test.com');
      await user.type(screen.getByPlaceholderText('María González'), 'Dup');

      const submitButton = screen.getByRole('button', { name: /Crear Inversor/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Email already exists');
      });

      alertSpy.mockRestore();
    });
  });

  describe('Eliminar inversor', () => {
    it('deletes investor after confirmation', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      vi.mocked(api.deleteInvestor).mockResolvedValue({});

      const user = userEvent.setup();
      renderWithRouter(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      await waitFor(() => {
        expect(screen.getByText('Eliminar Inversor')).toBeInTheDocument();
      });

      const confirmButtons = screen.getAllByRole('button', { name: 'Eliminar' });
      await user.click(confirmButtons[confirmButtons.length - 1]);

      await waitFor(() => {
        expect(api.deleteInvestor).toHaveBeenCalledWith('1');
      });

      expect(api.getAdminInvestors).toHaveBeenCalledTimes(2);
    });

    it('does not delete when confirmation is cancelled', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);

      const user = userEvent.setup();
      renderWithRouter(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      await waitFor(() => {
        expect(screen.getByText('Eliminar Inversor')).toBeInTheDocument();
      });

      const cancelButton = screen.getByRole('button', { name: 'Cancelar' });
      await user.click(cancelButton);

      expect(api.deleteInvestor).not.toHaveBeenCalled();
    });

    it('shows alert on delete error', async () => {
      vi.mocked(api.getAdminInvestors).mockResolvedValue(mockInvestors);
      vi.mocked(api.deleteInvestor).mockRejectedValue(new Error('Delete failed'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const user = userEvent.setup();

      renderWithRouter(<InvestorsPage />);

      await waitFor(() => {
        expect(api.getAdminInvestors).toHaveBeenCalled();
      });

      const deleteButtons = screen.getAllByTitle('Eliminar');
      await user.click(deleteButtons[0]);

      await waitFor(() => {
        expect(screen.getByText('Eliminar Inversor')).toBeInTheDocument();
      });

      const confirmButtons = screen.getAllByRole('button', { name: 'Eliminar' });
      await user.click(confirmButtons[confirmButtons.length - 1]);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Delete failed');
      });

      alertSpy.mockRestore();
    });
  });
});
