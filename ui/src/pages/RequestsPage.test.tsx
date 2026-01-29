import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { RequestsPage } from './RequestsPage';
import { api } from '../lib/api';

// Mock del módulo api
vi.mock('../lib/api', () => ({
  api: {
    getAdminRequests: vi.fn(),
    getAdminInvestors: vi.fn(),
    createRequest: vi.fn(),
    approveRequest: vi.fn(),
    rejectRequest: vi.fn(),
  },
}));

// Mock de window.confirm y window.alert
global.confirm = vi.fn(() => true);
global.alert = vi.fn();

describe('RequestsPage', () => {
  const mockInvestors = [
    { id: '1', email: 'inv1@test.com', name: 'Investor One' },
    { id: '2', email: 'inv2@test.com', name: 'Investor Two' },
  ];

  const mockRequests = {
    data: {
      requests: [
        {
          id: '1',
          investor: { id: '1', name: 'Investor One' },
          type: 'DEPOSIT',
          method: 'USDT',
          amount: 1000,
          network: 'TRC20',
          status: 'PENDING',
          requestedAt: '2024-01-01T10:00:00Z',
        },
        {
          id: '2',
          investor: { id: '2', name: 'Investor Two' },
          type: 'WITHDRAWAL',
          method: 'USDC',
          amount: 500,
          network: null,
          status: 'APPROVED',
          requestedAt: '2024-01-02T15:00:00Z',
          processedAt: '2024-01-03T10:00:00Z',
        },
      ],
      pendingCount: 1,
    },
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getAdminInvestors).mockResolvedValue({ data: mockInvestors });
  });

  describe('Listar solicitudes', () => {
    it('renders loading state initially', async () => {
      vi.mocked(api.getAdminRequests).mockImplementation(() => new Promise(() => {}));

      render(<RequestsPage />);

      await waitFor(() => {
        expect(screen.getByText('Cargando...')).toBeInTheDocument();
      });
    });

    it('renders requests list after loading', async () => {
      vi.mocked(api.getAdminRequests).mockResolvedValue(mockRequests);

      render(<RequestsPage />);

      // Wait for data to be rendered
      await waitFor(() => {
        expect(screen.getAllByText('Investor One').length).toBeGreaterThan(0);
      });

      expect(screen.getAllByText('Investor Two').length).toBeGreaterThan(0);
      expect(api.getAdminRequests).toHaveBeenCalled();
    });

    it('renders error message when fetch fails', async () => {
      vi.mocked(api.getAdminRequests).mockRejectedValue(new Error('Network error'));

      render(<RequestsPage />);

      await waitFor(() => {
        expect(screen.getByText('Network error')).toBeInTheDocument();
      });
    });

    it('shows pending count', async () => {
      vi.mocked(api.getAdminRequests).mockResolvedValue(mockRequests);

      render(<RequestsPage />);

      await waitFor(() => {
        expect(screen.getByText(/1 solicitud pendiente/i)).toBeInTheDocument();
      });
    });
  });

  describe('Filtros', () => {
    it('filters by status', async () => {
      vi.mocked(api.getAdminRequests).mockResolvedValue(mockRequests);

      render(<RequestsPage />);

      await waitFor(() => {
        expect(api.getAdminRequests).toHaveBeenCalled();
      });

      const statusSelect = screen.getByLabelText('Estado');
      fireEvent.change(statusSelect, { target: { value: 'PENDING' } });

      await waitFor(() => {
        expect(api.getAdminRequests).toHaveBeenCalledWith({ status: 'PENDING', type: undefined });
      });
    });

    it('filters by type', async () => {
      vi.mocked(api.getAdminRequests).mockResolvedValue(mockRequests);

      render(<RequestsPage />);

      await waitFor(() => {
        expect(api.getAdminRequests).toHaveBeenCalled();
      });

      const typeSelect = screen.getByLabelText('Tipo');
      fireEvent.change(typeSelect, { target: { value: 'DEPOSIT' } });

      await waitFor(() => {
        expect(api.getAdminRequests).toHaveBeenCalledWith({ status: undefined, type: 'DEPOSIT' });
      });
    });
  });

  describe('Crear solicitud', () => {
    it('shows form when "+ Agregar Solicitud" button is clicked', async () => {
      vi.mocked(api.getAdminRequests).mockResolvedValue(mockRequests);

      render(<RequestsPage />);

      await waitFor(() => {
        expect(api.getAdminRequests).toHaveBeenCalled();
      });

      const addButton = screen.getByRole('button', { name: /Agregar Solicitud/i });
      fireEvent.click(addButton);

      expect(screen.getByText('Nueva Solicitud')).toBeInTheDocument();
    });

    it('creates new request successfully', async () => {
      vi.mocked(api.getAdminRequests).mockResolvedValue(mockRequests);
      vi.mocked(api.createRequest).mockResolvedValue({ data: { id: '3' } });

      const user = userEvent.setup();
      render(<RequestsPage />);

      await waitFor(() => {
        expect(api.getAdminRequests).toHaveBeenCalled();
      });

      // Open form
      const addButton = screen.getByRole('button', { name: /Agregar Solicitud/i });
      await user.click(addButton);

      // Fill form
      const investorSelect = screen.getByLabelText(/Inversor/i);
      await user.selectOptions(investorSelect, '1');

      const typeSelect = screen.getByLabelText(/Tipo \*/i);
      await user.selectOptions(typeSelect, 'DEPOSIT');

      const amountInput = screen.getByPlaceholderText('1000');
      await user.type(amountInput, '2000');

      // Submit
      const submitButton = screen.getByRole('button', { name: /Crear Solicitud/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(api.createRequest).toHaveBeenCalledWith(
          expect.objectContaining({
            investor_id: '1',
            request_type: 'DEPOSIT',
            method: 'USDT',
            amount: 2000,
            status: 'PENDING',
          }),
        );
      });
    });

    it('shows alert on create error', async () => {
      vi.mocked(api.getAdminRequests).mockResolvedValue(mockRequests);
      vi.mocked(api.createRequest).mockRejectedValue(new Error('Create failed'));

      const alertSpy = vi.spyOn(window, 'alert').mockImplementation(() => {});
      const user = userEvent.setup();

      render(<RequestsPage />);

      await waitFor(() => {
        expect(api.getAdminRequests).toHaveBeenCalled();
      });

      const addButton = screen.getByRole('button', { name: /Agregar Solicitud/i });
      await user.click(addButton);

      const investorSelect = screen.getByLabelText(/Inversor/i);
      await user.selectOptions(investorSelect, '1');

      const amountInput = screen.getByPlaceholderText('1000');
      await user.type(amountInput, '1000');

      const submitButton = screen.getByRole('button', { name: /Crear Solicitud/i });
      await user.click(submitButton);

      await waitFor(() => {
        expect(alertSpy).toHaveBeenCalledWith('Create failed');
      });

      alertSpy.mockRestore();
    });
  });

  describe('Aprobar/Rechazar solicitud', () => {
    it('approves pending request', async () => {
      vi.mocked(api.getAdminRequests).mockResolvedValue(mockRequests);
      vi.mocked(api.approveRequest).mockResolvedValue({});

      const user = userEvent.setup();
      render(<RequestsPage />);

      await waitFor(() => {
        expect(api.getAdminRequests).toHaveBeenCalled();
      });

      const approveButtons = screen.getAllByRole('button', { name: /Aprobar/i });
      await user.click(approveButtons[0]);

      await waitFor(() => {
        expect(api.approveRequest).toHaveBeenCalledWith('1');
      });
    });

    it('rejects pending request', async () => {
      vi.mocked(api.getAdminRequests).mockResolvedValue(mockRequests);
      vi.mocked(api.rejectRequest).mockResolvedValue({});

      const user = userEvent.setup();
      render(<RequestsPage />);

      await waitFor(() => {
        expect(api.getAdminRequests).toHaveBeenCalled();
      });

      const rejectButtons = screen.getAllByRole('button', { name: /Rechazar/i });
      await user.click(rejectButtons[0]);

      await waitFor(() => {
        expect(api.rejectRequest).toHaveBeenCalledWith('1');
      });
    });
  });

});
