// Social Routes
import { Router } from 'express';
import socialController from './social.controller';
import { authenticateToken } from '../middleware/auth.middleware';

const router = Router();

// ===== POSTS =====

/**
 * @route   POST /api/social/posts
 * @desc    Create post
 * @access  Private
 */
router.post('/posts', authenticateToken, socialController.createPost);

/**
 * @route   GET /api/social/feed
 * @desc    Get feed (posts from followed users)
 * @access  Private
 */
router.get('/feed', authenticateToken, socialController.getFeed);

/**
 * @route   GET /api/social/users/:userId/posts
 * @desc    Get user's posts
 * @access  Public
 */
router.get('/users/:userId/posts', socialController.getUserPosts);

/**
 * @route   DELETE /api/social/posts/:id
 * @desc    Delete post
 * @access  Private
 */
router.delete('/posts/:id', authenticateToken, socialController.deletePost);

// ===== LIKES =====

/**
 * @route   POST /api/social/like
 * @desc    Like post
 * @access  Private
 */
router.post('/like', authenticateToken, socialController.likePost);

/**
 * @route   POST /api/social/unlike
 * @desc    Unlike post
 * @access  Private
 */
router.post('/unlike', authenticateToken, socialController.unlikePost);

// ===== COMMENTS =====

/**
 * @route   POST /api/social/comments
 * @desc    Add comment
 * @access  Private
 */
router.post('/comments', authenticateToken, socialController.addComment);

/**
 * @route   GET /api/social/posts/:postId/comments
 * @desc    Get comments for post
 * @access  Public
 */
router.get('/posts/:postId/comments', socialController.getComments);

/**
 * @route   DELETE /api/social/comments/:id
 * @desc    Delete comment
 * @access  Private
 */
router.delete('/comments/:id', authenticateToken, socialController.deleteComment);

// ===== FOLLOW =====

/**
 * @route   POST /api/social/follow
 * @desc    Follow user
 * @access  Private
 */
router.post('/follow', authenticateToken, socialController.followUser);

/**
 * @route   POST /api/social/unfollow
 * @desc    Unfollow user
 * @access  Private
 */
router.post('/unfollow', authenticateToken, socialController.unfollowUser);

/**
 * @route   GET /api/social/users/:userId/followers
 * @desc    Get user's followers
 * @access  Public
 */
router.get('/users/:userId/followers', socialController.getFollowers);

/**
 * @route   GET /api/social/users/:userId/following
 * @desc    Get users that user is following
 * @access  Public
 */
router.get('/users/:userId/following', socialController.getFollowing);

/**
 * @route   GET /api/social/users/:userId/is-following
 * @desc    Check if current user is following target user
 * @access  Private
 */
router.get('/users/:userId/is-following', authenticateToken, socialController.checkFollowing);

// ===== NOTIFICATIONS =====

/**
 * @route   GET /api/social/notifications
 * @desc    Get notifications
 * @access  Private
 */
router.get('/notifications', authenticateToken, socialController.getNotifications);

/**
 * @route   PUT /api/social/notifications/:id/read
 * @desc    Mark notification as read
 * @access  Private
 */
router.put('/notifications/:id/read', authenticateToken, socialController.markAsRead);

/**
 * @route   PUT /api/social/notifications/read-all
 * @desc    Mark all notifications as read
 * @access  Private
 */
router.put('/notifications/read-all', authenticateToken, socialController.markAllAsRead);

// ===== USER PROFILE =====

/**
 * @route   PUT /api/social/profile
 * @desc    Update user profile
 * @access  Private
 */
router.put('/profile', authenticateToken, socialController.updateProfile);

/**
 * @route   GET /api/social/users/:userId
 * @desc    Get user profile with stats
 * @access  Public
 */
router.get('/users/:userId', socialController.getUserProfile);

export default router;
