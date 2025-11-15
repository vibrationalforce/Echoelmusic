/**
 * Echoelmusic Backend API Server
 * Node.js + Express REST API for social features, user management, and cloud sync
 *
 * Features:
 * - User authentication (JWT)
 * - Social features (feed, likes, comments, follows)
 * - Cloud sync coordination
 * - Payment webhook handling
 * - Analytics tracking
 * - File upload management
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
const { createClient } = require('@supabase/supabase-js');
const Stripe = require('stripe');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
require('dotenv').config();

// Initialize Express
const app = express();
const PORT = process.env.PORT || 3000;

// Initialize Supabase (Database & Storage)
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

// Initialize Stripe
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// Middleware
app.use(helmet()); // Security headers
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(morgan('combined')); // Logging

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/', limiter);

// Authentication middleware
const authenticateJWT = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (authHeader) {
    const token = authHeader.split(' ')[1];

    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
      if (err) {
        return res.sendStatus(403);
      }

      req.user = user;
      next();
    });
  } else {
    res.sendStatus(401);
  }
};

// ==================== ROUTES ====================

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// ==================== AUTH ROUTES ====================

// Register
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, username, password } = req.body;

    // Validate input
    if (!email || !username || !password) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Check if user exists
    const { data: existingUser } = await supabase
      .from('users')
      .select('id')
      .or(`email.eq.${email},username.eq.${username}`)
      .single();

    if (existingUser) {
      return res.status(409).json({ error: 'User already exists' });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create user
    const { data: user, error } = await supabase
      .from('users')
      .insert([
        {
          email,
          username,
          password_hash: passwordHash,
          created_at: new Date().toISOString()
        }
      ])
      .select()
      .single();

    if (error) throw error;

    // Generate JWT
    const token = jwt.sign(
      { id: user.id, email: user.email, username: user.username },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        username: user.username
      },
      token
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// Login
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Get user
    const { data: user, error } = await supabase
      .from('users')
      .select('*')
      .eq('email', email)
      .single();

    if (error || !user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Verify password
    const validPassword = await bcrypt.compare(password, user.password_hash);

    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate JWT
    const token = jwt.sign(
      { id: user.id, email: user.email, username: user.username },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        display_name: user.display_name,
        avatar_url: user.avatar_url
      },
      token
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

// Get current user
app.get('/api/auth/me', authenticateJWT, async (req, res) => {
  try {
    const { data: user, error } = await supabase
      .from('users')
      .select('id, email, username, display_name, bio, avatar_url, created_at')
      .eq('id', req.user.id)
      .single();

    if (error) throw error;

    res.json(user);
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Failed to get user' });
  }
});

// ==================== USER ROUTES ====================

// Get user profile
app.get('/api/users/:username', async (req, res) => {
  try {
    const { data: user, error } = await supabase
      .from('users')
      .select('id, username, display_name, bio, avatar_url, created_at')
      .eq('username', req.params.username)
      .single();

    if (error) throw error;

    // Get stats
    const { count: projectCount } = await supabase
      .from('projects')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('is_public', true);

    const { count: followers } = await supabase
      .from('follows')
      .select('*', { count: 'exact', head: true })
      .eq('following_id', user.id);

    const { count: following } = await supabase
      .from('follows')
      .select('*', { count: 'exact', head: true })
      .eq('follower_id', user.id);

    res.json({
      ...user,
      project_count: projectCount,
      followers,
      following
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(404).json({ error: 'User not found' });
  }
});

// Update user profile
app.put('/api/users/me', authenticateJWT, async (req, res) => {
  try {
    const { display_name, bio, avatar_url } = req.body;

    const { data: user, error } = await supabase
      .from('users')
      .update({
        display_name,
        bio,
        avatar_url,
        updated_at: new Date().toISOString()
      })
      .eq('id', req.user.id)
      .select()
      .single();

    if (error) throw error;

    res.json(user);
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

// ==================== PROJECT ROUTES ====================

// Get feed (projects from followed users)
app.get('/api/feed', authenticateJWT, async (req, res) => {
  try {
    const { limit = 20, offset = 0 } = req.query;

    // Get followed user IDs
    const { data: follows } = await supabase
      .from('follows')
      .select('following_id')
      .eq('follower_id', req.user.id);

    const followingIds = follows.map(f => f.following_id);

    // Get projects from followed users
    const { data: projects, error } = await supabase
      .from('projects')
      .select(`
        *,
        user:users(id, username, display_name, avatar_url),
        likes:project_likes(count),
        comments:project_comments(count)
      `)
      .in('user_id', followingIds)
      .eq('is_public', true)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) throw error;

    res.json(projects);
  } catch (error) {
    console.error('Get feed error:', error);
    res.status(500).json({ error: 'Failed to get feed' });
  }
});

// Get trending projects
app.get('/api/projects/trending', async (req, res) => {
  try {
    const { limit = 20 } = req.query;

    // Get projects with most likes in last 7 days
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

    const { data: projects, error } = await supabase
      .from('projects')
      .select(`
        *,
        user:users(id, username, display_name, avatar_url),
        likes:project_likes(count)
      `)
      .eq('is_public', true)
      .gte('created_at', sevenDaysAgo)
      .order('likes_count', { ascending: false })
      .limit(limit);

    if (error) throw error;

    res.json(projects);
  } catch (error) {
    console.error('Get trending error:', error);
    res.status(500).json({ error: 'Failed to get trending projects' });
  }
});

// Create project
app.post('/api/projects', authenticateJWT, async (req, res) => {
  try {
    const { title, description, genre, tags, is_public, cover_art_url } = req.body;

    const { data: project, error } = await supabase
      .from('projects')
      .insert([
        {
          user_id: req.user.id,
          title,
          description,
          genre,
          tags,
          is_public,
          cover_art_url,
          created_at: new Date().toISOString()
        }
      ])
      .select()
      .single();

    if (error) throw error;

    res.status(201).json(project);
  } catch (error) {
    console.error('Create project error:', error);
    res.status(500).json({ error: 'Failed to create project' });
  }
});

// Like project
app.post('/api/projects/:id/like', authenticateJWT, async (req, res) => {
  try {
    const { data: like, error } = await supabase
      .from('project_likes')
      .insert([
        {
          project_id: req.params.id,
          user_id: req.user.id,
          created_at: new Date().toISOString()
        }
      ])
      .select()
      .single();

    if (error) {
      if (error.code === '23505') { // Unique violation
        return res.status(409).json({ error: 'Already liked' });
      }
      throw error;
    }

    // Increment like count
    await supabase.rpc('increment_likes', { project_id: req.params.id });

    res.status(201).json(like);
  } catch (error) {
    console.error('Like project error:', error);
    res.status(500).json({ error: 'Failed to like project' });
  }
});

// Comment on project
app.post('/api/projects/:id/comments', authenticateJWT, async (req, res) => {
  try {
    const { text } = req.body;

    const { data: comment, error } = await supabase
      .from('project_comments')
      .insert([
        {
          project_id: req.params.id,
          user_id: req.user.id,
          text,
          created_at: new Date().toISOString()
        }
      ])
      .select(`
        *,
        user:users(id, username, display_name, avatar_url)
      `)
      .single();

    if (error) throw error;

    res.status(201).json(comment);
  } catch (error) {
    console.error('Comment error:', error);
    res.status(500).json({ error: 'Failed to create comment' });
  }
});

// ==================== FOLLOW ROUTES ====================

// Follow user
app.post('/api/users/:username/follow', authenticateJWT, async (req, res) => {
  try {
    // Get user ID
    const { data: user } = await supabase
      .from('users')
      .select('id')
      .eq('username', req.params.username)
      .single();

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const { data: follow, error } = await supabase
      .from('follows')
      .insert([
        {
          follower_id: req.user.id,
          following_id: user.id,
          created_at: new Date().toISOString()
        }
      ])
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        return res.status(409).json({ error: 'Already following' });
      }
      throw error;
    }

    res.status(201).json(follow);
  } catch (error) {
    console.error('Follow error:', error);
    res.status(500).json({ error: 'Failed to follow user' });
  }
});

// ==================== STRIPE WEBHOOKS ====================

app.post('/api/webhooks/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle event
  switch (event.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated':
      const subscription = event.data.object;
      await handleSubscriptionUpdate(subscription);
      break;

    case 'customer.subscription.deleted':
      const deletedSubscription = event.data.object;
      await handleSubscriptionCancellation(deletedSubscription);
      break;

    case 'invoice.payment_succeeded':
      const invoice = event.data.object;
      await handleSuccessfulPayment(invoice);
      break;

    case 'invoice.payment_failed':
      const failedInvoice = event.data.object;
      await handleFailedPayment(failedInvoice);
      break;

    default:
      console.log(`Unhandled event type ${event.type}`);
  }

  res.json({ received: true });
});

async function handleSubscriptionUpdate(subscription) {
  // Update user subscription status in database
  await supabase
    .from('subscriptions')
    .upsert({
      user_id: subscription.metadata.user_id,
      stripe_subscription_id: subscription.id,
      stripe_customer_id: subscription.customer,
      status: subscription.status,
      plan: subscription.items.data[0].price.id,
      current_period_end: new Date(subscription.current_period_end * 1000).toISOString()
    });
}

async function handleSubscriptionCancellation(subscription) {
  await supabase
    .from('subscriptions')
    .update({
      status: 'canceled',
      canceled_at: new Date().toISOString()
    })
    .eq('stripe_subscription_id', subscription.id);
}

async function handleSuccessfulPayment(invoice) {
  // Log successful payment
  console.log('Payment succeeded:', invoice.id);
}

async function handleFailedPayment(invoice) {
  // Send notification to user about failed payment
  console.log('Payment failed:', invoice.id);
}

// ==================== START SERVER ====================

app.listen(PORT, () => {
  console.log(`🚀 Echoelmusic API server running on port ${PORT}`);
  console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔒 CORS origin: ${process.env.CORS_ORIGIN || '*'}`);
});

module.exports = app;
