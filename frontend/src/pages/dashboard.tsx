import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import Link from 'next/link';
import api from '@/lib/api';
import { format } from 'date-fns';
import { FiLogOut, FiSettings, FiDownload, FiPlus, FiTrash2 } from 'react-icons/fi';

interface User {
  id: string;
  email: string;
  name: string | null;
  subscription: string;
  subscriptionStatus: string;
  trialEndsAt: string | null;
  isTrialActive: boolean;
}

interface Project {
  id: string;
  title: string;
  description: string | null;
  tempo: number;
  platform: string;
  createdAt: string;
  updatedAt: string;
}

export default function Dashboard() {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!api.isAuthenticated()) {
      router.push('/login');
      return;
    }

    loadData();
  }, [router]);

  const loadData = async () => {
    try {
      const [profileData, projectsData] = await Promise.all([
        api.getProfile(),
        api.getProjects(),
      ]);

      setUser(profileData);
      setProjects(projectsData.data || []);
    } catch (err) {
      console.error('Failed to load data:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleUpgrade = async () => {
    try {
      const { url } = await api.createCheckoutSession(
        'PRO_MONTHLY',
        `${window.location.origin}/dashboard?success=true`,
        `${window.location.origin}/dashboard?canceled=true`
      );
      window.location.href = url;
    } catch (err) {
      console.error('Failed to create checkout session:', err);
    }
  };

  const handleManageSubscription = async () => {
    try {
      const { url } = await api.createPortalSession(`${window.location.origin}/dashboard`);
      window.location.href = url;
    } catch (err) {
      console.error('Failed to create portal session:', err);
    }
  };

  const handleLogout = () => {
    api.logout();
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p className="text-gray-400">Loading...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="bg-dark-surface border-b border-gray-700">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center">
            <h1 className="text-2xl font-bold gradient-text">Echoelmusic</h1>
            <div className="flex items-center gap-4">
              <Link href="/settings" className="text-gray-400 hover:text-white">
                <FiSettings size={20} />
              </Link>
              <button onClick={handleLogout} className="text-gray-400 hover:text-white">
                <FiLogOut size={20} />
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Welcome Section */}
        <div className="mb-8">
          <h2 className="text-3xl font-bold mb-2">
            Welcome back{user?.name ? `, ${user.name}` : ''}!
          </h2>
          <p className="text-gray-400">{user?.email}</p>
        </div>

        {/* Subscription Card */}
        <div className="card mb-8">
          <div className="flex justify-between items-start">
            <div>
              <h3 className="text-xl font-bold mb-2">Subscription</h3>
              <div className="space-y-2">
                <p className="text-2xl font-bold text-primary-500">
                  {user?.subscription === 'FREE' ? 'Free Trial' : user?.subscription}
                </p>
                {user?.isTrialActive && user?.trialEndsAt && (
                  <p className="text-sm text-gray-400">
                    Trial ends: {format(new Date(user.trialEndsAt), 'MMM dd, yyyy')}
                  </p>
                )}
                <p className="text-sm text-gray-400">
                  Status: <span className="capitalize">{user?.subscriptionStatus.toLowerCase()}</span>
                </p>
              </div>
            </div>
            <div className="space-y-2">
              {user?.subscription === 'FREE' ? (
                <button onClick={handleUpgrade} className="btn btn-primary">
                  Upgrade to Pro - €29/mo
                </button>
              ) : (
                <button onClick={handleManageSubscription} className="btn btn-secondary">
                  Manage Subscription
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Projects Section */}
        <div className="card">
          <div className="flex justify-between items-center mb-6">
            <h3 className="text-xl font-bold">Your Projects</h3>
            <Link href="/projects/new" className="btn btn-primary flex items-center gap-2">
              <FiPlus /> New Project
            </Link>
          </div>

          {projects.length === 0 ? (
            <div className="text-center py-12 text-gray-400">
              <p className="mb-4">No projects yet</p>
              <Link href="/projects/new" className="btn btn-secondary">
                Create Your First Project
              </Link>
            </div>
          ) : (
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {projects.map((project) => (
                <div key={project.id} className="bg-dark-bg p-4 rounded-lg hover:bg-opacity-80 transition">
                  <h4 className="font-bold mb-2">{project.title}</h4>
                  {project.description && (
                    <p className="text-sm text-gray-400 mb-2">{project.description}</p>
                  )}
                  <div className="flex justify-between items-center text-xs text-gray-500">
                    <span>{project.tempo} BPM</span>
                    <span>{project.platform}</span>
                  </div>
                  <div className="mt-3 text-xs text-gray-500">
                    Updated: {format(new Date(project.updatedAt), 'MMM dd, yyyy')}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Download Desktop App */}
        <div className="card mt-8">
          <h3 className="text-xl font-bold mb-4">Download Desktop App</h3>
          <p className="text-gray-400 mb-6">
            Get the full Echoelmusic DAW experience with 80+ effects and biofeedback integration.
          </p>
          <div className="flex gap-4">
            <button className="btn btn-primary flex items-center gap-2">
              <FiDownload /> Windows
            </button>
            <button className="btn btn-primary flex items-center gap-2">
              <FiDownload /> macOS
            </button>
            <button className="btn btn-primary flex items-center gap-2">
              <FiDownload /> Linux
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}
