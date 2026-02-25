import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { EditInvestorPage } from './EditInvestorPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getAdminInvestors: vi.fn(),
    updateInvestor: vi.fn(),
  },
}));

const renderRoute = () =>
  render(
    <MemoryRouter initialEntries={['/investors/1/edit']}>
      <Routes>
        <Route path="/investors/:id/edit" element={<EditInvestorPage />} />
        <Route path="/investors" element={<div>Investors list</div>} />
      </Routes>
    </MemoryRouter>,
  );

describe('EditInvestorPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('loads investor and shows form', async () => {
    vi.mocked(api.getAdminInvestors).mockResolvedValue({
      data: [
        {
          id: '1',
          email: 'inv@test.com',
          name: 'Investor One',
          status: 'ACTIVE',
          tradingFeeFrequency: 'QUARTERLY',
          tradingFeePercentage: 30,
        },
      ],
    } as { data?: unknown[] });

    renderRoute();

    await waitFor(() => expect(screen.getByDisplayValue('inv@test.com')).toBeInTheDocument());
    expect(screen.getByDisplayValue('Investor One')).toBeInTheDocument();
    expect(screen.getByText('Editar Inversor')).toBeInTheDocument();
  });

  it('updates investor and navigates on success', async () => {
    vi.mocked(api.getAdminInvestors).mockResolvedValue({
      data: [
        {
          id: '1',
          email: 'inv@test.com',
          name: 'Original',
          status: 'ACTIVE',
          tradingFeeFrequency: 'QUARTERLY',
          tradingFeePercentage: 30,
        },
      ],
    } as { data?: unknown[] });
    vi.mocked(api.updateInvestor).mockResolvedValue(null);

    const user = userEvent.setup();
    renderRoute();

    await waitFor(() => expect(screen.getByDisplayValue('Original')).toBeInTheDocument());
    const nameInput = screen.getByDisplayValue('Original') as HTMLInputElement;
    await user.clear(nameInput);
    await user.type(nameInput, 'Updated Name');
    await user.click(screen.getByRole('button', { name: /Guardar/i }));

    await waitFor(() => {
      expect(api.updateInvestor).toHaveBeenCalledWith(
        '1',
        expect.objectContaining({
          email: 'inv@test.com',
          name: 'Updated Name',
          status: 'ACTIVE',
          trading_fee_frequency: 'QUARTERLY',
          trading_fee_percentage: 30,
        }),
      );
    });
    await waitFor(() => expect(screen.getByText('Investors list')).toBeInTheDocument());
  });
});
