/**
 * Analytics API Routes
 * Provides endpoints for analytics dashboard and business metrics
 */

const express = require('express');
const router = express.Router();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

/**
 * Authenticate admin requests
 */
const authenticateAdmin = async (req, res, next) => {
  const token = req.headers.authorization?.replace('Bearer ', '');

  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const { data: { user }, error } = await supabase.auth.getUser(token);

    if (error || !user || !user.user_metadata?.is_admin) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

/**
 * GET /analytics/dashboard
 * Returns comprehensive dashboard metrics
 */
router.get('/dashboard', authenticateAdmin, async (req, res) => {
  try {
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    // Fetch users
    const { data: allUsers } = await supabase
      .from('users')
      .select('id, created_at');

    const { data: recentUsers } = await supabase
      .from('users')
      .select('id')
      .gte('created_at', sevenDaysAgo.toISOString());

    const { data: monthOldUsers } = await supabase
      .from('users')
      .select('id')
      .gte('created_at', thirtyDaysAgo.toISOString())
      .lt('created_at', sevenDaysAgo.toISOString());

    // Fetch subscriptions
    const { data: subscriptions } = await supabase
      .from('subscriptions')
      .select('*')
      .eq('status', 'active');

    const { data: recentSubs } = await supabase
      .from('subscriptions')
      .select('*')
      .eq('status', 'active')
      .gte('created_at', sevenDaysAgo.toISOString());

    // Fetch projects
    const { data: allProjects } = await supabase
      .from('projects')
      .select('id, created_at');

    const { data: recentProjects } = await supabase
      .from('projects')
      .select('id')
      .gte('created_at', sevenDaysAgo.toISOString());

    // Calculate metrics
    const totalUsers = allUsers?.length || 0;
    const previousWeekUsers = totalUsers - (recentUsers?.length || 0);
    const totalUsersChange = previousWeekUsers > 0
      ? ((recentUsers?.length || 0) / previousWeekUsers * 100) - 100
      : 0;

    const mau = await getMonthlyActiveUsers(thirtyDaysAgo);
    const previousMau = await getMonthlyActiveUsers(
      new Date(thirtyDaysAgo.getTime() - 30 * 24 * 60 * 60 * 1000)
    );
    const mauChange = previousMau > 0 ? ((mau - previousMau) / previousMau * 100) : 0;

    const mrr = calculateMRR(subscriptions);
    const previousMrr = calculateMRR(
      subscriptions?.filter(s =>
        new Date(s.created_at) < sevenDaysAgo
      )
    );
    const mrrChange = previousMrr > 0 ? ((mrr - previousMrr) / previousMrr * 100) : 0;

    const totalProjects = allProjects?.length || 0;
    const previousProjects = totalProjects - (recentProjects?.length || 0);
    const totalProjectsChange = previousProjects > 0
      ? ((recentProjects?.length || 0) / previousProjects * 100) - 100
      : 0;

    const paidUsers = subscriptions?.length || 0;
    const conversionRate = totalUsers > 0 ? (paidUsers / totalUsers * 100) : 0;
    const previousConversionRate = previousWeekUsers > 0
      ? ((paidUsers - (recentSubs?.length || 0)) / previousWeekUsers * 100)
      : 0;
    const conversionRateChange = previousConversionRate > 0
      ? conversionRate - previousConversionRate
      : 0;

    const churnRate = await calculateChurnRate(sevenDaysAgo, now);
    const previousChurnRate = await calculateChurnRate(
      new Date(sevenDaysAgo.getTime() - 7 * 24 * 60 * 60 * 1000),
      sevenDaysAgo
    );
    const churnRateChange = churnRate - previousChurnRate;

    const arpu = totalUsers > 0 ? mrr / totalUsers : 0;
    const previousArpu = previousWeekUsers > 0 ? previousMrr / previousWeekUsers : 0;
    const arpuChange = previousArpu > 0 ? ((arpu - previousArpu) / previousArpu * 100) : 0;

    // User growth data (30 days)
    const userGrowth = await getUserGrowthData(30);

    // Revenue breakdown
    const revenueBreakdown = {
      labels: ['Free', 'Pro', 'Studio'],
      data: [
        totalUsers - paidUsers,
        subscriptions?.filter(s => s.tier === 'Pro').length || 0,
        subscriptions?.filter(s => s.tier === 'Studio').length || 0
      ]
    };

    // MRR history (6 months)
    const mrrHistory = await getMRRHistory(6);

    // Feature usage
    const featureUsage = await getFeatureUsage();

    // Project activity (7 days)
    const projectActivity = await getProjectActivity(7);

    // Conversion funnel
    const conversionFunnel = await getConversionFunnel();

    // Build response
    const response = {
      metrics: {
        totalUsers,
        totalUsersChange: parseFloat(totalUsersChange.toFixed(1)),
        mau,
        mauChange: parseFloat(mauChange.toFixed(1)),
        mrr: parseFloat(mrr.toFixed(2)),
        mrrChange: parseFloat(mrrChange.toFixed(1)),
        arr: parseFloat((mrr * 12).toFixed(2)),
        arrChange: parseFloat(mrrChange.toFixed(1)),
        totalProjects,
        totalProjectsChange: parseFloat(totalProjectsChange.toFixed(1)),
        conversionRate: parseFloat(conversionRate.toFixed(1)),
        conversionRateChange: parseFloat(conversionRateChange.toFixed(1)),
        churnRate: parseFloat(churnRate.toFixed(1)),
        churnRateChange: parseFloat(churnRateChange.toFixed(1)),
        arpu: parseFloat(arpu.toFixed(2)),
        arpuChange: parseFloat(arpuChange.toFixed(1))
      },
      userGrowth,
      revenueBreakdown,
      mrr: mrrHistory,
      featureUsage,
      projectActivity,
      conversionFunnel
    };

    res.json(response);
  } catch (error) {
    console.error('Error fetching dashboard data:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Helper: Get monthly active users
 */
async function getMonthlyActiveUsers(sinceDate) {
  const { data } = await supabase
    .from('user_activity')
    .select('user_id')
    .gte('timestamp', sinceDate.toISOString());

  const uniqueUsers = new Set(data?.map(a => a.user_id) || []);
  return uniqueUsers.size;
}

/**
 * Helper: Calculate MRR
 */
function calculateMRR(subscriptions) {
  if (!subscriptions || subscriptions.length === 0) return 0;

  return subscriptions.reduce((sum, sub) => {
    if (sub.status !== 'active') return sum;

    let monthlyAmount = sub.amount;
    if (sub.billing_cycle === 'annual') {
      monthlyAmount = sub.amount / 12;
    }

    return sum + monthlyAmount;
  }, 0);
}

/**
 * Helper: Calculate churn rate
 */
async function calculateChurnRate(startDate, endDate) {
  const { data: cancelledSubs } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('status', 'cancelled')
    .gte('cancelled_at', startDate.toISOString())
    .lte('cancelled_at', endDate.toISOString());

  const { data: activeSubs } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('status', 'active');

  if (!activeSubs || activeSubs.length === 0) return 0;

  const churnedCount = cancelledSubs?.length || 0;
  const totalSubscribers = activeSubs.length + churnedCount;

  return totalSubscribers > 0 ? (churnedCount / totalSubscribers * 100) : 0;
}

/**
 * Helper: Get user growth data
 */
async function getUserGrowthData(days) {
  const labels = [];
  const data = [];

  for (let i = days - 1; i >= 0; i--) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    date.setHours(0, 0, 0, 0);

    const { count } = await supabase
      .from('users')
      .select('*', { count: 'exact', head: true })
      .lte('created_at', date.toISOString());

    labels.push(date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }));
    data.push(count || 0);
  }

  return { labels, data };
}

/**
 * Helper: Get MRR history
 */
async function getMRRHistory(months) {
  const labels = [];
  const data = [];

  for (let i = months - 1; i >= 0; i--) {
    const date = new Date();
    date.setMonth(date.getMonth() - i);

    const monthStart = new Date(date.getFullYear(), date.getMonth(), 1);
    const monthEnd = new Date(date.getFullYear(), date.getMonth() + 1, 0);

    const { data: subs } = await supabase
      .from('subscriptions')
      .select('*')
      .eq('status', 'active')
      .lte('created_at', monthEnd.toISOString());

    const mrr = calculateMRR(subs);

    labels.push(date.toLocaleDateString('en-US', { month: 'short' }));
    data.push(parseFloat(mrr.toFixed(2)));
  }

  return { labels, data };
}

/**
 * Helper: Get feature usage statistics
 */
async function getFeatureUsage() {
  const features = [
    'ai_auto_mix',
    'cloud_sync',
    '3d_visualizer',
    'mpe',
    'automation',
    'video_export'
  ];

  const labels = [];
  const data = [];

  for (const feature of features) {
    const { count } = await supabase
      .from('feature_usage')
      .select('*', { count: 'exact', head: true })
      .eq('feature_name', feature);

    labels.push(
      feature
        .split('_')
        .map(w => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ')
    );
    data.push(count || 0);
  }

  return { labels, data };
}

/**
 * Helper: Get project activity
 */
async function getProjectActivity(days) {
  const labels = [];
  const data = [];

  for (let i = days - 1; i >= 0; i--) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    const dayStart = new Date(date.setHours(0, 0, 0, 0));
    const dayEnd = new Date(date.setHours(23, 59, 59, 999));

    const { count } = await supabase
      .from('projects')
      .select('*', { count: 'exact', head: true })
      .gte('created_at', dayStart.toISOString())
      .lte('created_at', dayEnd.toISOString());

    labels.push(date.toLocaleDateString('en-US', { weekday: 'short' }));
    data.push(count || 0);
  }

  return { labels, data };
}

/**
 * Helper: Get conversion funnel data
 */
async function getConversionFunnel() {
  const { count: signups } = await supabase
    .from('users')
    .select('*', { count: 'exact', head: true });

  const { count: createdProject } = await supabase
    .from('users')
    .select('*', { count: 'exact', head: true })
    .not('first_project_at', 'is', null);

  const { count: exported } = await supabase
    .from('users')
    .select('*', { count: 'exact', head: true })
    .not('first_export_at', 'is', null);

  const { count: startedTrial } = await supabase
    .from('users')
    .select('*', { count: 'exact', head: true })
    .not('trial_started_at', 'is', null);

  const { count: converted } = await supabase
    .from('subscriptions')
    .select('*', { count: 'exact', head: true })
    .eq('status', 'active');

  return {
    labels: ['Signups', 'Created Project', 'Exported', 'Started Trial', 'Converted'],
    data: [signups || 0, createdProject || 0, exported || 0, startedTrial || 0, converted || 0]
  };
}

/**
 * GET /analytics/export
 * Export analytics data as CSV
 */
router.get('/export', authenticateAdmin, async (req, res) => {
  try {
    const { data: users } = await supabase
      .from('users')
      .select('*')
      .order('created_at', { ascending: false });

    // Generate CSV
    const csv = [
      ['User ID', 'Email', 'Tier', 'Created At', 'Projects', 'Exports'].join(','),
      ...users.map(u => [
        u.id,
        u.email,
        u.tier || 'Free',
        u.created_at,
        u.projects_count || 0,
        u.exports_count || 0
      ].join(','))
    ].join('\n');

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=echoelmusic-analytics.csv');
    res.send(csv);
  } catch (error) {
    console.error('Error exporting analytics:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
