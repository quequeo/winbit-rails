import { API_BASE_URL } from '../lib/api';
import { Button } from '../components/ui/Button';

export const LoginPage = () => {
  const url = `${API_BASE_URL}/users/auth/google_oauth2`;

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
      <div className="w-full max-w-md rounded-xl bg-white shadow p-8">
        <h1 className="text-2xl font-bold text-gray-900">Winbit Admin</h1>
        <p className="text-sm text-gray-600 mt-1">Ingresá con Google</p>

        <div className="mt-6">
          <a href={url}>
            <Button className="w-full">Ingresar con Google</Button>
          </a>
        </div>

        <p className="mt-4 text-xs text-gray-500">
          Solo admins autorizados pueden acceder.
        </p>
      </div>
    </div>
  );
};
