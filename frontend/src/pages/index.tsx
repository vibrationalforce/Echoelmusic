import { useEffect } from 'react';
import { useRouter } from 'next/router';
import api from '@/lib/api';

export default function Home() {
  const router = useRouter();

  useEffect(() => {
    // Redirect to dashboard if authenticated, otherwise to login
    if (api.isAuthenticated()) {
      router.push('/dashboard');
    } else {
      router.push('/login');
    }
  }, [router]);

  return (
    <div className="flex items-center justify-center min-h-screen">
      <div className="text-center">
        <h1 className="text-4xl font-bold gradient-text mb-4">Echoelmusic</h1>
        <p className="text-gray-400">Loading...</p>
      </div>
    </div>
  );
}
