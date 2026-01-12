import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { EditPortfolioPage } from './EditPortfolioPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getAdminPortfolios: vi.fn(),
    updatePortfolio: vi.fn(),
  },
}));

const mockNavigate = vi.fn();
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  };
});

describe('EditPortfolioPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const renderWithRouter = (id: string = '1') => {
    return render(
      <MemoryRouter initialEntries={[`/portfolios/${id}/edit`]}>
        <Routes>
          <Route path="/portfolios/:id/edit" element={<EditPortfolioPage />} />
        </Routes>
      </MemoryRouter>,
    );
  };

  it('renders loading state initially', () => {
    vi.mocked(api.getAdminPortfolios).mockReturnValue(new Promise(() => {}));
    renderWithRouter();
    expect(screen.getByText('Cargando...')).toBeInTheDocument();
  });

  it('renders portfolio data when loaded', async () => {
    const mockData = {
      data: [
        {
          id: '1',
          name: 'Test Investor',
          portfolio: {
            current_balance: 10000,
            total_invested: 8000,
            accumulated_return_usd: 2000,
            accumulated_return_percent: 25,
            annual_return_usd: 1500,
            annual_return_percent: 18.75,
          },
        },
      ],
    };

    vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);

    renderWithRouter('1');

    await waitFor(() => {
      expect(screen.getByText('Editar Portfolio')).toBeInTheDocument();
    });

    expect(screen.getByText('Test Investor')).toBeInTheDocument();
    expect(screen.getByText('Capital Actual (USD)')).toBeInTheDocument();
    expect(screen.getByText('Total Invertido (USD)')).toBeInTheDocument();
  });

  it('renders error when investor not found', async () => {
    const mockData = {
      data: [
        {
          id: '2',
          name: 'Other Investor',
          portfolio: {},
        },
      ],
    };

    vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);

    renderWithRouter('1');

    await waitFor(() => {
      expect(screen.getByText('No se encontró el inversor/portfolio')).toBeInTheDocument();
    });
  });

  it('renders error when fetch fails', async () => {
    vi.mocked(api.getAdminPortfolios).mockRejectedValueOnce(new Error('Network error'));

    renderWithRouter();

    await waitFor(() => {
      expect(screen.getByText('Network error')).toBeInTheDocument();
    });
  });

  it('renders form with submit buttons', async () => {
    const mockData = {
      data: [
        {
          id: '1',
          name: 'Test Investor',
          portfolio: {
            current_balance: 10000,
            total_invested: 8000,
            accumulated_return_usd: 2000,
            accumulated_return_percent: 25,
            annual_return_usd: 1500,
            annual_return_percent: 18.75,
          },
        },
      ],
    };

    vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);

    renderWithRouter('1');

    await waitFor(() => {
      expect(screen.getByText('Editar Portfolio')).toBeInTheDocument();
    });

    expect(screen.getByText('Guardar Cambios')).toBeInTheDocument();
    expect(screen.getByText('Cancelar')).toBeInTheDocument();
  });

  it('submits form successfully', async () => {
    const mockData = {
      data: [
        {
          id: '1',
          name: 'Test Investor',
          portfolio: {
            current_balance: 10000,
            total_invested: 8000,
            accumulated_return_usd: 2000,
            accumulated_return_percent: 25,
            annual_return_usd: 1500,
            annual_return_percent: 18.75,
          },
        },
      ],
    };

    vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);
    vi.mocked(api.updatePortfolio).mockResolvedValueOnce({});

    renderWithRouter('1');

    await waitFor(() => {
      expect(screen.getByText('Editar Portfolio')).toBeInTheDocument();
    });

    const submitButton = screen.getByText('Guardar Cambios');
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(api.updatePortfolio).toHaveBeenCalled();
    });

    expect(mockNavigate).toHaveBeenCalledWith('/portfolios');
  });

  it('handles submit error', async () => {
    const mockData = {
      data: [
        {
          id: '1',
          name: 'Test Investor',
          portfolio: {
            current_balance: 10000,
            total_invested: 8000,
            accumulated_return_usd: 2000,
            accumulated_return_percent: 25,
            annual_return_usd: 1500,
            annual_return_percent: 18.75,
          },
        },
      ],
    };

    vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);
    vi.mocked(api.updatePortfolio).mockRejectedValueOnce(new Error('Update failed'));

    renderWithRouter('1');

    await waitFor(() => {
      expect(screen.getByText('Editar Portfolio')).toBeInTheDocument();
    });

    const submitButton = screen.getByText('Guardar Cambios');
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText('Update failed')).toBeInTheDocument();
    });
  });

  it('navigates back on cancel button click', async () => {
    const mockData = {
      data: [
        {
          id: '1',
          name: 'Test Investor',
          portfolio: {
            current_balance: 10000,
            total_invested: 8000,
            accumulated_return_usd: 2000,
            accumulated_return_percent: 25,
            annual_return_usd: 1500,
            annual_return_percent: 18.75,
          },
        },
      ],
    };

    vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);

    renderWithRouter('1');

    await waitFor(() => {
      expect(screen.getByText('Editar Portfolio')).toBeInTheDocument();
    });

    const cancelButton = screen.getByText('Cancelar');
    fireEvent.click(cancelButton);

    expect(mockNavigate).toHaveBeenCalledWith('/portfolios');
  });

  it('navigates back on volver button click', async () => {
    const mockData = {
      data: [
        {
          id: '1',
          name: 'Test Investor',
          portfolio: {
            current_balance: 10000,
            total_invested: 8000,
            accumulated_return_usd: 2000,
            accumulated_return_percent: 25,
            annual_return_usd: 1500,
            annual_return_percent: 18.75,
          },
        },
      ],
    };

    vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);

    renderWithRouter('1');

    await waitFor(() => {
      expect(screen.getByText('Editar Portfolio')).toBeInTheDocument();
    });

    const volverButton = screen.getByText('Volver');
    fireEvent.click(volverButton);

    expect(mockNavigate).toHaveBeenCalledWith('/portfolios');
  });

  it('handles portfolio without existing data', async () => {
    const mockData = {
      data: [
        {
          id: '1',
          name: 'New Investor',
          portfolio: null,
        },
      ],
    };

    vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);

    renderWithRouter('1');

    await waitFor(() => {
      expect(screen.getByText('Editar Portfolio')).toBeInTheDocument();
    });

    // Should use default values of 0
    const inputs = screen.getAllByDisplayValue('0');
    expect(inputs.length).toBeGreaterThan(0);
  });

  it('renders all form labels correctly', async () => {
    const mockData = {
      data: [
        {
          id: '1',
          name: 'Test Investor',
          portfolio: {
            current_balance: 10000,
            total_invested: 8000,
            accumulated_return_usd: 2000,
            accumulated_return_percent: 25,
            annual_return_usd: 1500,
            annual_return_percent: 18.75,
          },
        },
      ],
    };

    vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);

    renderWithRouter('1');

    await waitFor(() => {
      expect(screen.getByText('Editar Portfolio')).toBeInTheDocument();
    });

    // Check all form labels are present
    expect(screen.getByText('Capital Actual (USD)')).toBeInTheDocument();
    expect(screen.getByText('Total Invertido (USD)')).toBeInTheDocument();
    expect(screen.getByText('Rend. Acum. desde el Inicio (USD)')).toBeInTheDocument();
    expect(screen.getByText('Rend. Acum. (%)')).toBeInTheDocument();
    expect(screen.getByText('Rend. Acum. Anual (USD)')).toBeInTheDocument();
    expect(screen.getByText('Rend. Acum. Anual (%)')).toBeInTheDocument();
  });

  describe('Form field updates', () => {
    const mockData = {
      data: [
        {
          id: '1',
          name: 'Test Investor',
          portfolio: {
            current_balance: 10000,
            total_invested: 8000,
            accumulated_return_usd: 2000,
            accumulated_return_percent: 25,
            annual_return_usd: 1500,
            annual_return_percent: 18.75,
          },
        },
      ],
    };

    it('updates currentBalance field', async () => {
      vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);
      renderWithRouter('1');

      await waitFor(() => {
        expect(screen.getByText('Editar Portfolio')).toBeInTheDocument();
      });

      const inputs = screen.getAllByDisplayValue('10000');
      // currentBalance should be the first one
      const input = inputs[0];
      fireEvent.change(input, { target: { value: '15000' } });

      expect(input).toHaveValue(15000);
    });

    it('updates totalInvested field', async () => {
      vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);
      renderWithRouter('1');

      let input;
      await waitFor(() => {
        input = screen.getByDisplayValue('8000');
        expect(input).toBeInTheDocument();
      });

      fireEvent.change(input!, { target: { value: '9000' } });

      expect(input).toHaveValue(9000);
    });

    it('auto-calculates accumulatedReturnUSD field', async () => {
      vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);
      renderWithRouter('1');

      // Wait for the accumulated return USD field to be auto-calculated
      // Current balance = 10000, Total invested = 8000, so return = 2000
      await waitFor(() => {
        const accReturnInput = screen.getByDisplayValue('2000');
        expect(accReturnInput).toBeInTheDocument();
        expect(accReturnInput).toBeDisabled(); // Should be read-only
      });
    });

    it('auto-calculates accumulatedReturnPercent field', async () => {
      vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);
      renderWithRouter('1');

      // Wait for the accumulated return % field to be auto-calculated
      // (10000 - 8000) / 8000 * 100 = 25%
      await waitFor(() => {
        const accReturnPercentInput = screen.getByDisplayValue('25');
        expect(accReturnPercentInput).toBeInTheDocument();
        expect(accReturnPercentInput).toBeDisabled(); // Should be read-only
      });
    });

    it('updates annualReturnUSD field', async () => {
      vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);
      renderWithRouter('1');

      let input;
      await waitFor(() => {
        input = screen.getByDisplayValue('1500');
        expect(input).toBeInTheDocument();
      });

      fireEvent.change(input!, { target: { value: '2500' } });

      expect(input).toHaveValue(2500);
    });

    it('updates annualReturnPercent field', async () => {
      vi.mocked(api.getAdminPortfolios).mockResolvedValueOnce(mockData);
      renderWithRouter('1');

      let input;
      await waitFor(() => {
        input = screen.getByDisplayValue('18.75');
        expect(input).toBeInTheDocument();
      });

      fireEvent.change(input!, { target: { value: '20' } });

      expect(input).toHaveValue(20);
    });
  });
});
