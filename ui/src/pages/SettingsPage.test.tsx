import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { SettingsPage } from './SettingsPage';
import { api } from '../lib/api';

vi.mock('../lib/api', () => ({
  api: {
    getAdminSettings: vi.fn(),
    updateAdminSettings: vi.fn(),
  },
}));

describe('SettingsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.getAdminSettings).mockResolvedValue({
      data: {
        investor_notifications_enabled: true,
        investor_email_whitelist: ['a@test.com', 'b@test.com'],
      },
    } as { data?: Record<string, unknown> });
  });

  it('loads and displays settings', async () => {
    render(<SettingsPage />);

    await waitFor(() => {
      expect(screen.getByText('Configuración')).toBeInTheDocument();
    });

    expect(api.getAdminSettings).toHaveBeenCalled();
    await waitFor(() => {
      const textarea = screen.getByRole('textbox');
      expect(textarea).toHaveValue('a@test.com, b@test.com');
    });
  });

  it('saves settings on button click', async () => {
    vi.mocked(api.updateAdminSettings).mockResolvedValue(null);

    const user = userEvent.setup();
    render(<SettingsPage />);

    await waitFor(() => expect(screen.getByText('Configuración')).toBeInTheDocument());

    const saveBtn = screen.getByRole('button', { name: /Guardar Configuración/i });
    await user.click(saveBtn);

    await waitFor(() => {
      expect(api.updateAdminSettings).toHaveBeenCalledWith(
        expect.objectContaining({
          investor_notifications_enabled: true,
          investor_email_whitelist: expect.any(Array),
        }),
      );
    });
  });
});
