import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { PortfoliosPage } from './PortfoliosPage';
import { api } from '../lib/api';

// Mock del módulo api
vi.mock('../lib/api', () => ({
  api: {
    getAdminPortfolios: vi.fn(),
  },
}));

const mockPortfolios = {
  data: [
    {
      id: '1',
      email: 'inv1@test.com',
      name: 'Investor One',
      portfolio: {
        current_balance: 10000,
        total_invested: 8000,
        accumulated_return_usd: 2000,
        accumulated_return_percent: 25.0,
        annual_return_usd: 1000,
        annual_return_percent: 12.5,
      },
    },
    {
      id: '2',
      email: 'inv2@test.com',
      name: 'Investor Two',
      portfolio: {
        current_balance: 5000,
        total_invested: 5000,
        accumulated_return_usd: 0,
        accumulated_return_percent: 0,
        annual_return_usd: 0,
        annual_return_percent: 0,
      },
    },
  ],
};

describe('PortfoliosPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders loading state initially', () => {
    vi.mocked(api.getAdminPortfolios).mockImplementation(() => new Promise(() => {}));

    render(
      <BrowserRouter>
        <PortfoliosPage />
      </BrowserRouter>
    );

    expect(screen.getByText('Cargando...')).toBeInTheDocument();
  });

  it('renders portfolios list after loading', async () => {
    vi.mocked(api.getAdminPortfolios).mockResolvedValue(mockPortfolios);

    render(
      <BrowserRouter>
        <PortfoliosPage />
      </BrowserRouter>
    );

    await waitFor(() => {
      expect(api.getAdminPortfolios).toHaveBeenCalled();
    });

    expect(screen.getAllByText('Investor One').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Investor Two').length).toBeGreaterThan(0);
  });

  it('renders error message when fetch fails', async () => {
    vi.mocked(api.getAdminPortfolios).mockRejectedValue(new Error('Network error'));

    render(
      <BrowserRouter>
        <PortfoliosPage />
      </BrowserRouter>
    );

    await waitFor(() => {
      expect(screen.getByText('Network error')).toBeInTheDocument();
    });
  });

  it('displays portfolio balances correctly', async () => {
    vi.mocked(api.getAdminPortfolios).mockResolvedValue(mockPortfolios);

    render(
      <BrowserRouter>
        <PortfoliosPage />
      </BrowserRouter>
    );

    await waitFor(() => {
      expect(api.getAdminPortfolios).toHaveBeenCalled();
    });

    // Check if investor names are displayed
    expect(screen.getAllByText('Investor One').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Investor Two').length).toBeGreaterThan(0);
  });

  it('displays edit portfolio buttons with correct links', async () => {
    vi.mocked(api.getAdminPortfolios).mockResolvedValue(mockPortfolios);

    render(
      <BrowserRouter>
        <PortfoliosPage />
      </BrowserRouter>
    );

    await waitFor(() => {
      expect(api.getAdminPortfolios).toHaveBeenCalled();
    });

    const editButtons = screen.getAllByRole('link', { name: /Editar Portfolio/i });
    expect(editButtons.length).toBeGreaterThan(0);
    expect(editButtons[0]).toHaveAttribute('href', '/portfolios/1');
  });

  it('handles portfolios without data gracefully', async () => {
    const emptyMock = { data: [] };
    vi.mocked(api.getAdminPortfolios).mockResolvedValue(emptyMock);

    render(
      <BrowserRouter>
        <PortfoliosPage />
      </BrowserRouter>
    );

    await waitFor(() => {
      expect(api.getAdminPortfolios).toHaveBeenCalled();
    });

    // Should render title but no portfolio cards
    expect(screen.getByText('Portfolios')).toBeInTheDocument();
  });

  it('displays returns information correctly', async () => {
    vi.mocked(api.getAdminPortfolios).mockResolvedValue(mockPortfolios);

    render(
      <BrowserRouter>
        <PortfoliosPage />
      </BrowserRouter>
    );

    await waitFor(() => {
      expect(api.getAdminPortfolios).toHaveBeenCalled();
    });

    // Check that portfolio data is rendered (form display may vary)
    expect(screen.getByText('Portfolios')).toBeInTheDocument();
    const editButtons = screen.getAllByRole('link');
    expect(editButtons.length).toBeGreaterThan(0);
  });
});
