/**
 * Analytics Tracking System
 * Integrates with Mixpanel for user analytics and business metrics
 * Tracks MAU, conversion rates, churn, revenue, and feature adoption
 */

const Mixpanel = require('mixpanel');
const { createClient } = require('@supabase/supabase-js');

class AnalyticsTracking {
  constructor(config) {
    this.mixpanel = Mixpanel.init(config.mixpanelToken);
    this.supabase = createClient(config.supabaseUrl, config.supabaseKey);
  }

  /**
   * Track user event
   */
  trackEvent(userId, eventName, properties = {}) {
    this.mixpanel.track(eventName, {
      distinct_id: userId,
      ...properties,
      timestamp: new Date().toISOString()
    });

    console.log(`📊 Tracked: ${eventName} for user ${userId}`);
  }

  /**
   * Identify user with profile properties
   */
  identifyUser(userId, properties) {
    this.mixpanel.people.set(userId, {
      ...properties,
      $last_seen: new Date().toISOString()
    });

    console.log(`👤 Identified user: ${userId}`);
  }

  /**
   * Track user signup
   */
  trackSignup(userId, properties) {
    this.trackEvent(userId, 'User Signup', {
      platform: properties.platform || 'unknown',
      source: properties.source || 'organic',
      tier: 'Free'
    });

    this.identifyUser(userId, {
      $email: properties.email,
      $created: new Date().toISOString(),
      tier: 'Free',
      platform: properties.platform
    });
  }

  /**
   * Track project creation
   */
  trackProjectCreated(userId, projectData) {
    this.trackEvent(userId, 'Project Created', {
      project_type: projectData.type || 'Audio',
      template: projectData.template || 'Blank',
      user_tier: projectData.userTier || 'Free'
    });

    // Increment project count
    this.mixpanel.people.increment(userId, 'projects_created', 1);
  }

  /**
   * Track export/render
   */
  trackExport(userId, exportData) {
    this.trackEvent(userId, 'Export Completed', {
      format: exportData.format,
      duration: exportData.duration,
      quality: exportData.quality,
      user_tier: exportData.userTier
    });

    this.mixpanel.people.increment(userId, 'exports_total', 1);
  }

  /**
   * Track feature usage
   */
  trackFeatureUsed(userId, featureName, metadata = {}) {
    this.trackEvent(userId, 'Feature Used', {
      feature: featureName,
      ...metadata
    });

    // Track feature-specific properties
    this.mixpanel.people.set_once(userId, `first_${featureName}_use`, new Date().toISOString());
    this.mixpanel.people.increment(userId, `${featureName}_uses`, 1);
  }

  /**
   * Track subscription events
   */
  trackSubscriptionStarted(userId, subscriptionData) {
    this.trackEvent(userId, 'Subscription Started', {
      tier: subscriptionData.tier,
      price: subscriptionData.price,
      billing_cycle: subscriptionData.billingCycle,
      payment_method: subscriptionData.paymentMethod
    });

    this.identifyUser(userId, {
      tier: subscriptionData.tier,
      $revenue: subscriptionData.price,
      subscription_started: new Date().toISOString()
    });
  }

  trackSubscriptionCancelled(userId, reason) {
    this.trackEvent(userId, 'Subscription Cancelled', {
      reason: reason,
      cancelled_at: new Date().toISOString()
    });

    this.identifyUser(userId, {
      tier: 'Free',
      churn_reason: reason,
      churned_at: new Date().toISOString()
    });
  }

  /**
   * Track payment events
   */
  trackPaymentReceived(userId, paymentData) {
    this.trackEvent(userId, 'Payment Received', {
      amount: paymentData.amount,
      currency: paymentData.currency,
      payment_method: paymentData.paymentMethod,
      tier: paymentData.tier
    });

    this.mixpanel.people.track_charge(userId, paymentData.amount, {
      $time: new Date().toISOString(),
      tier: paymentData.tier
    });
  }

  trackPaymentFailed(userId, paymentData) {
    this.trackEvent(userId, 'Payment Failed', {
      amount: paymentData.amount,
      error: paymentData.error,
      tier: paymentData.tier
    });
  }

  /**
   * Calculate and report business metrics
   */
  async generateBusinessMetrics(startDate, endDate) {
    console.log('\n📈 Generating Business Metrics Report...\n');

    // Get user data from Supabase
    const { data: users } = await this.supabase
      .from('users')
      .select('*')
      .gte('created_at', startDate)
      .lte('created_at', endDate);

    const { data: subscriptions } = await this.supabase
      .from('subscriptions')
      .select('*')
      .eq('status', 'active');

    const { data: projects } = await this.supabase
      .from('projects')
      .select('*')
      .gte('created_at', startDate)
      .lte('created_at', endDate);

    // Calculate metrics
    const metrics = {
      // User Metrics
      totalUsers: users?.length || 0,
      newUsers: users?.filter(u =>
        new Date(u.created_at) >= new Date(startDate)
      ).length || 0,
      activeUsers: await this.getActiveUsers(startDate, endDate),

      // Subscription Metrics
      totalSubscriptions: subscriptions?.length || 0,
      proSubscriptions: subscriptions?.filter(s => s.tier === 'Pro').length || 0,
      studioSubscriptions: subscriptions?.filter(s => s.tier === 'Studio').length || 0,

      // Revenue Metrics
      mrr: this.calculateMRR(subscriptions),
      arr: this.calculateMRR(subscriptions) * 12,
      arpu: this.calculateARPU(subscriptions, users?.length || 0),

      // Engagement Metrics
      totalProjects: projects?.length || 0,
      projectsPerUser: (projects?.length || 0) / (users?.length || 1),

      // Conversion Metrics
      conversionRate: this.calculateConversionRate(users, subscriptions),
      churnRate: await this.calculateChurnRate(startDate, endDate),

      // Period
      period: {
        start: startDate,
        end: endDate
      }
    };

    // Display report
    console.log('═══════════════════════════════════════════');
    console.log('  ECHOELMUSIC BUSINESS METRICS REPORT');
    console.log('═══════════════════════════════════════════');
    console.log(`  Period: ${startDate} to ${endDate}`);
    console.log('───────────────────────────────────────────');
    console.log('  USER METRICS:');
    console.log(`    Total Users:        ${metrics.totalUsers}`);
    console.log(`    New Users:          ${metrics.newUsers}`);
    console.log(`    Active Users (MAU): ${metrics.activeUsers}`);
    console.log('───────────────────────────────────────────');
    console.log('  SUBSCRIPTION METRICS:');
    console.log(`    Total Subscriptions: ${metrics.totalSubscriptions}`);
    console.log(`    Pro Tier:            ${metrics.proSubscriptions}`);
    console.log(`    Studio Tier:         ${metrics.studioSubscriptions}`);
    console.log('───────────────────────────────────────────');
    console.log('  REVENUE METRICS:');
    console.log(`    MRR (Monthly):       €${metrics.mrr.toFixed(2)}`);
    console.log(`    ARR (Annual):        €${metrics.arr.toFixed(2)}`);
    console.log(`    ARPU:                €${metrics.arpu.toFixed(2)}`);
    console.log('───────────────────────────────────────────');
    console.log('  ENGAGEMENT METRICS:');
    console.log(`    Total Projects:      ${metrics.totalProjects}`);
    console.log(`    Projects/User:       ${metrics.projectsPerUser.toFixed(2)}`);
    console.log('───────────────────────────────────────────');
    console.log('  CONVERSION METRICS:');
    console.log(`    Conversion Rate:     ${(metrics.conversionRate * 100).toFixed(2)}%`);
    console.log(`    Churn Rate:          ${(metrics.churnRate * 100).toFixed(2)}%`);
    console.log('═══════════════════════════════════════════\n');

    return metrics;
  }

  /**
   * Get active users count (MAU)
   */
  async getActiveUsers(startDate, endDate) {
    // Query Mixpanel for unique users who had activity in the period
    // This is a simplified version - actual implementation would use Mixpanel's query API
    const { data } = await this.supabase
      .from('user_activity')
      .select('user_id')
      .gte('timestamp', startDate)
      .lte('timestamp', endDate);

    const uniqueUsers = new Set(data?.map(a => a.user_id) || []);
    return uniqueUsers.size;
  }

  /**
   * Calculate Monthly Recurring Revenue
   */
  calculateMRR(subscriptions) {
    if (!subscriptions || subscriptions.length === 0) return 0;

    return subscriptions.reduce((sum, sub) => {
      if (sub.status !== 'active') return sum;

      // Convert to monthly amount
      let monthlyAmount = sub.amount;
      if (sub.billing_cycle === 'annual') {
        monthlyAmount = sub.amount / 12;
      }

      return sum + monthlyAmount;
    }, 0);
  }

  /**
   * Calculate Average Revenue Per User
   */
  calculateARPU(subscriptions, totalUsers) {
    if (totalUsers === 0) return 0;
    const mrr = this.calculateMRR(subscriptions);
    return mrr / totalUsers;
  }

  /**
   * Calculate conversion rate (free to paid)
   */
  calculateConversionRate(users, subscriptions) {
    if (!users || users.length === 0) return 0;
    const paidUsers = subscriptions?.filter(s => s.status === 'active').length || 0;
    return paidUsers / users.length;
  }

  /**
   * Calculate churn rate
   */
  async calculateChurnRate(startDate, endDate) {
    const { data: cancelledSubs } = await this.supabase
      .from('subscriptions')
      .select('*')
      .eq('status', 'cancelled')
      .gte('cancelled_at', startDate)
      .lte('cancelled_at', endDate);

    const { data: activeSubs } = await this.supabase
      .from('subscriptions')
      .select('*')
      .eq('status', 'active');

    if (!activeSubs || activeSubs.length === 0) return 0;

    const churnedCount = cancelledSubs?.length || 0;
    const totalSubscribers = activeSubs.length + churnedCount;

    return churnedCount / totalSubscribers;
  }

  /**
   * Generate weekly automated report
   */
  async generateWeeklyReport() {
    const today = new Date();
    const weekAgo = new Date(today);
    weekAgo.setDate(weekAgo.getDate() - 7);

    const metrics = await this.generateBusinessMetrics(
      weekAgo.toISOString(),
      today.toISOString()
    );

    // Send to Slack webhook
    if (process.env.SLACK_WEBHOOK) {
      await this.sendSlackReport(metrics);
    }

    return metrics;
  }

  /**
   * Send metrics report to Slack
   */
  async sendSlackReport(metrics) {
    const axios = require('axios');

    const message = {
      text: '📊 Weekly Echoelmusic Metrics Report',
      blocks: [
        {
          type: 'header',
          text: {
            type: 'plain_text',
            text: '📊 Weekly Metrics Report'
          }
        },
        {
          type: 'section',
          fields: [
            { type: 'mrkdwn', text: `*Total Users:*\n${metrics.totalUsers}` },
            { type: 'mrkdwn', text: `*New Users:*\n${metrics.newUsers}` },
            { type: 'mrkdwn', text: `*MAU:*\n${metrics.activeUsers}` },
            { type: 'mrkdwn', text: `*MRR:*\n€${metrics.mrr.toFixed(2)}` }
          ]
        },
        {
          type: 'section',
          fields: [
            { type: 'mrkdwn', text: `*Conversion:*\n${(metrics.conversionRate * 100).toFixed(2)}%` },
            { type: 'mrkdwn', text: `*Churn:*\n${(metrics.churnRate * 100).toFixed(2)}%` },
            { type: 'mrkdwn', text: `*Projects:*\n${metrics.totalProjects}` },
            { type: 'mrkdwn', text: `*Projects/User:*\n${metrics.projectsPerUser.toFixed(2)}` }
          ]
        }
      ]
    };

    try {
      await axios.post(process.env.SLACK_WEBHOOK, message);
      console.log('✅ Sent weekly report to Slack');
    } catch (error) {
      console.error('❌ Failed to send Slack report:', error.message);
    }
  }
}

// CLI Usage
async function main() {
  const config = {
    mixpanelToken: process.env.MIXPANEL_TOKEN,
    supabaseUrl: process.env.SUPABASE_URL,
    supabaseKey: process.env.SUPABASE_SERVICE_KEY
  };

  const analytics = new AnalyticsTracking(config);

  const command = process.argv[2];

  switch (command) {
    case 'weekly':
      // Generate and send weekly report
      await analytics.generateWeeklyReport();
      break;

    case 'metrics':
      // Generate metrics for specified period
      const startDate = process.argv[3] || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
      const endDate = process.argv[4] || new Date().toISOString();
      await analytics.generateBusinessMetrics(startDate, endDate);
      break;

    default:
      console.log('Usage:');
      console.log('  node analytics-tracking.js weekly           # Generate weekly report');
      console.log('  node analytics-tracking.js metrics [start] [end]  # Generate metrics for period');
  }
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = AnalyticsTracking;
