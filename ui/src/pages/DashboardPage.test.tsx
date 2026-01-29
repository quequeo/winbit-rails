import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { DashboardPage } from './DashboardPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getAdminDashboard: vi.fn(),
  },
}));

describe('DashboardPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders loading state initially', () => {
    vi.mocked(api.getAdminDashboard).mockReturnValue(new Promise(() => {}));
    render(<DashboardPage />);
    expect(screen.getByText('Cargando...')).toBeInTheDocument();
  });

  it('renders dashboard data when loaded', async () => {
    const mockData = {
      data: {
        investorCount: 25,
        pendingRequestCount: 3,
        totalAum: 150000,
      },
    };

    vi.mocked(api.getAdminDashboard).mockResolvedValueOnce(mockData);

    render(<DashboardPage />);

    await waitFor(() => {
      expect(screen.getByText('Dashboard')).toBeInTheDocument();
    });

    expect(screen.getByText('Total Inversores')).toBeInTheDocument();
    expect(screen.getByText('25')).toBeInTheDocument();

    expect(screen.getByText('Capital Total Administrado')).toBeInTheDocument();
    // Argentine format: $150.000,00
    expect(screen.getByText(/\$150\.000,00/)).toBeInTheDocument();

    expect(screen.getByText('Solicitudes Pendientes')).toBeInTheDocument();

    expect(screen.getByRole('group', { name: 'Rango de tiempo del gráfico' })).toBeInTheDocument();
    expect(screen.getByText('7 días')).toBeInTheDocument();
    expect(screen.getByText('1 mes')).toBeInTheDocument();
    expect(screen.getByText('3 meses')).toBeInTheDocument();
    expect(screen.getByText('6 meses')).toBeInTheDocument();
    expect(screen.getByText('1 año')).toBeInTheDocument();
    expect(screen.getByText('Todo')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument();
  });

  it('renders error message when fetch fails', async () => {
    vi.mocked(api.getAdminDashboard).mockRejectedValueOnce(new Error('Network error'));

    render(<DashboardPage />);

    await waitFor(() => {
      expect(screen.getByText('Network error')).toBeInTheDocument();
    });
  });

  it('formats large AUM values correctly', async () => {
    const mockData = {
      data: {
        investorCount: 100,
        pendingRequestCount: 5,
        totalAum: 1234567.89,
      },
    };

    vi.mocked(api.getAdminDashboard).mockResolvedValueOnce(mockData);

    render(<DashboardPage />);

    await waitFor(() => {
      // Argentine format: $1.234.567,89
      expect(screen.getByText(/\$1\.234\.567,89/)).toBeInTheDocument();
    });
  });

  it('handles zero values correctly', async () => {
    const mockData = {
      data: {
        investorCount: 0,
        pendingRequestCount: 0,
        totalAum: 0,
      },
    };

    vi.mocked(api.getAdminDashboard).mockResolvedValueOnce(mockData);

    render(<DashboardPage />);

    await waitFor(() => {
      expect(screen.getByText('Dashboard')).toBeInTheDocument();
    });

    // Argentine format: $0,00
    expect(screen.getAllByText(/\$0,00/).length).toBeGreaterThan(0);
    const zeroElements = screen.getAllByText('0');
    expect(zeroElements.length).toBeGreaterThanOrEqual(2);
  });

  it('cleans up on unmount to prevent memory leaks', async () => {
    const mockData = {
      data: {
        investorCount: 10,
        pendingRequestCount: 2,
        totalAum: 50000,
      },
    };

    vi.mocked(api.getAdminDashboard).mockResolvedValueOnce(mockData);

    const { unmount } = render(<DashboardPage />);

    await waitFor(() => {
      expect(screen.getByText('Dashboard')).toBeInTheDocument();
    });

    // Unmount should not cause any errors or warnings
    unmount();
    expect(api.getAdminDashboard).toHaveBeenCalledTimes(1);
  });
});
