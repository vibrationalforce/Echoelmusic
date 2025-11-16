// Authentication Service
import { PrismaClient, User } from '@prisma/client';
import { hashPassword, comparePassword, validatePasswordStrength } from '../utils/password.utils';
import { generateToken } from '../utils/jwt.utils';
import { AppError } from '../middleware/error.middleware';

const prisma = new PrismaClient();

export interface RegisterInput {
  email: string;
  password: string;
  name?: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface AuthResponse {
  user: {
    id: string;
    email: string;
    name: string | null;
    subscription: string;
    trialEndsAt: Date | null;
  };
  token: string;
}

export class AuthService {
  async register(input: RegisterInput): Promise<AuthResponse> {
    const { email, password, name } = input;

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new AppError('Invalid email format', 400);
    }

    // Validate password strength
    const passwordValidation = validatePasswordStrength(password);
    if (!passwordValidation.valid) {
      throw new AppError(
        `Password validation failed: ${passwordValidation.errors.join(', ')}`,
        400
      );
    }

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email }
    });

    if (existingUser) {
      throw new AppError('User with this email already exists', 409);
    }

    // Hash password
    const hashedPassword = await hashPassword(password);

    // Calculate trial end date (30 days from now)
    const trialEndsAt = new Date();
    trialEndsAt.setDate(trialEndsAt.getDate() + 30);

    // Create user
    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        name: name || null,
        subscription: 'FREE',
        subscriptionStatus: 'TRIALING',
        trialEndsAt,
        isTrialActive: true
      }
    });

    // Generate JWT token
    const token = generateToken({
      userId: user.id,
      email: user.email
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        subscription: user.subscription,
        trialEndsAt: user.trialEndsAt
      },
      token
    };
  }

  async login(input: LoginInput): Promise<AuthResponse> {
    const { email, password } = input;

    // Find user
    const user = await prisma.user.findUnique({
      where: { email }
    });

    if (!user) {
      throw new AppError('Invalid email or password', 401);
    }

    // Verify password
    const isPasswordValid = await comparePassword(password, user.password);
    if (!isPasswordValid) {
      throw new AppError('Invalid email or password', 401);
    }

    // Update last login time
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() }
    });

    // Generate JWT token
    const token = generateToken({
      userId: user.id,
      email: user.email
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        subscription: user.subscription,
        trialEndsAt: user.trialEndsAt
      },
      token
    };
  }

  async getProfile(userId: string): Promise<User | null> {
    return prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        subscription: true,
        subscriptionStatus: true,
        trialEndsAt: true,
        isTrialActive: true,
        createdAt: true,
        lastLoginAt: true,
        // Don't return password
        password: false
      }
    }) as Promise<User | null>;
  }

  async updateProfile(userId: string, data: { name?: string }): Promise<User> {
    return prisma.user.update({
      where: { id: userId },
      data,
      select: {
        id: true,
        email: true,
        name: true,
        subscription: true,
        subscriptionStatus: true,
        trialEndsAt: true,
        isTrialActive: true,
        createdAt: true,
        lastLoginAt: true,
        password: false
      }
    }) as Promise<User>;
  }
}

export default new AuthService();
