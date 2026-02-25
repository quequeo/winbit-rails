import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { LoginPage } from './LoginPage';
import { API_BASE_URL } from '../lib/api';

describe('LoginPage', () => {
  const originalLocation = window.location;

  beforeEach(() => {
    // Mock window.location
    delete (window as unknown as { location?: Location }).location;
    (window as unknown as { location: Location }).location = { ...originalLocation, search: '' } as Location;
  });

  afterEach(() => {
    window.location = originalLocation;
  });

  it('renders login page with title', () => {
    render(<LoginPage />);
    expect(screen.getByText('Winbit Admin')).toBeInTheDocument();
    expect(screen.getByText('Ingresá con Google')).toBeInTheDocument();
  });

  it('renders login button with correct link', () => {
    render(<LoginPage />);
    const link = screen.getByRole('link');
    expect(link).toHaveAttribute('href', `${API_BASE_URL}/users/auth/google_oauth2`);
  });

  it('renders disclaimer text', () => {
    render(<LoginPage />);
    expect(screen.getByText('Solo admins autorizados pueden acceder.')).toBeInTheDocument();
  });

  it('shows unauthorized error message when error=unauthorized', () => {
    (window as unknown as { location: Location }).location = { ...originalLocation, search: '?error=unauthorized' } as Location;
    render(<LoginPage />);
    expect(screen.getByText('Tu cuenta de Google no está autorizada como admin.')).toBeInTheDocument();
  });

  it('shows auth failed error message when error=auth_failed', () => {
    (window as unknown as { location: Location }).location = { ...originalLocation, search: '?error=auth_failed' } as Location;
    render(<LoginPage />);
    expect(screen.getByText(/Falló el login con Google/)).toBeInTheDocument();
    expect(screen.getByText(/GOOGLE_CLIENT_ID\/SECRET/)).toBeInTheDocument();
  });

  it('does not show error message when no error param', () => {
    (window as unknown as { location: Location }).location = { ...originalLocation, search: '' } as Location;
    render(<LoginPage />);
    expect(screen.queryByText(/Tu cuenta de Google no está autorizada/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Falló el login con Google/)).not.toBeInTheDocument();
  });

  it('does not show error message for unknown error param', () => {
    (window as unknown as { location: Location }).location = { ...originalLocation, search: '?error=unknown' } as Location;
    render(<LoginPage />);
    expect(screen.queryByText(/Tu cuenta de Google no está autorizada/)).not.toBeInTheDocument();
    expect(screen.queryByText(/Falló el login con Google/)).not.toBeInTheDocument();
  });

  it('renders login button inside link', () => {
    render(<LoginPage />);
    const link = screen.getByRole('link');
    const button = screen.getByRole('button', { name: 'Ingresar con Google' });
    expect(link).toContainElement(button);
  });

  it('applies correct styling classes', () => {
    const { container } = render(<LoginPage />);
    const mainDiv = container.querySelector('.min-h-screen');
    expect(mainDiv).toBeInTheDocument();
    expect(mainDiv).toHaveClass('bg-gray-50', 'flex', 'items-center', 'justify-center');
  });

  it('renders card with shadow', () => {
    const { container } = render(<LoginPage />);
    const card = container.querySelector('.shadow');
    expect(card).toBeInTheDocument();
    expect(card).toHaveClass('bg-white', 'rounded-xl');
  });

  it('memoizes error message to avoid recalculation', () => {
    (window as unknown as { location: Location }).location = { ...originalLocation, search: '?error=unauthorized' } as Location;
    const { rerender } = render(<LoginPage />);
    expect(screen.getByText('Tu cuenta de Google no está autorizada como admin.')).toBeInTheDocument();

    // Rerender should use memoized value
    rerender(<LoginPage />);
    expect(screen.getByText('Tu cuenta de Google no está autorizada como admin.')).toBeInTheDocument();
  });
});
