import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { PlaceholderPage } from './PlaceholderPage';

describe('PlaceholderPage', () => {
  it('renders title and message', () => {
    render(<PlaceholderPage title="Página en construcción" />);

    expect(screen.getByRole('heading', { name: 'Página en construcción' })).toBeInTheDocument();
    expect(screen.getByText('Pendiente de migrar (UI completa).')).toBeInTheDocument();
  });
});
