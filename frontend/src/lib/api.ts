// API Client
import axios, { AxiosInstance, AxiosError } from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

class ApiClient {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: `${API_URL}/api`,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor to add auth token
    this.client.interceptors.request.use(
      (config) => {
        const token = this.getToken();
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => Promise.reject(error)
    );

    // Response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        if (error.response?.status === 401) {
          // Token expired or invalid
          this.clearToken();
          if (typeof window !== 'undefined') {
            window.location.href = '/login';
          }
        }
        return Promise.reject(error);
      }
    );
  }

  private getToken(): string | null {
    if (typeof window !== 'undefined') {
      return localStorage.getItem('token');
    }
    return null;
  }

  private setToken(token: string): void {
    if (typeof window !== 'undefined') {
      localStorage.setItem('token', token);
    }
  }

  private clearToken(): void {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('token');
    }
  }

  // Auth endpoints
  async register(email: string, password: string, name?: string) {
    const { data } = await this.client.post('/auth/register', { email, password, name });
    if (data.data.token) {
      this.setToken(data.data.token);
    }
    return data.data;
  }

  async login(email: string, password: string) {
    const { data } = await this.client.post('/auth/login', { email, password });
    if (data.data.token) {
      this.setToken(data.data.token);
    }
    return data.data;
  }

  async getProfile() {
    const { data } = await this.client.get('/auth/profile');
    return data.data;
  }

  async updateProfile(updates: { name?: string }) {
    const { data } = await this.client.put('/auth/profile', updates);
    return data.data;
  }

  logout() {
    this.clearToken();
    if (typeof window !== 'undefined') {
      window.location.href = '/login';
    }
  }

  // Payment endpoints
  async getPlans() {
    const { data } = await this.client.get('/payments/plans');
    return data.data;
  }

  async createCheckoutSession(planKey: string, successUrl: string, cancelUrl: string) {
    const { data } = await this.client.post('/payments/checkout', {
      planKey,
      successUrl,
      cancelUrl,
    });
    return data.data;
  }

  async createPortalSession(returnUrl: string) {
    const { data } = await this.client.post('/payments/portal', { returnUrl });
    return data.data;
  }

  // Project endpoints
  async getProjects(page: number = 1, limit: number = 20) {
    const { data } = await this.client.get('/projects', { params: { page, limit } });
    return data;
  }

  async getProject(id: string) {
    const { data } = await this.client.get(`/projects/${id}`);
    return data.data;
  }

  async createProject(projectData: { title: string; description?: string; tempo?: number }) {
    const { data } = await this.client.post('/projects', projectData);
    return data.data;
  }

  async deleteProject(id: string) {
    const { data } = await this.client.delete(`/projects/${id}`);
    return data;
  }

  isAuthenticated(): boolean {
    return !!this.getToken();
  }
}

export const api = new ApiClient();
export default api;
