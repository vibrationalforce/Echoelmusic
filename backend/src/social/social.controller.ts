// Social Controller
import { Response } from 'express';
import { asyncHandler } from '../middleware/error.middleware';
import { AuthRequest } from '../middleware/auth.middleware';
import socialService from './social.service';

export class SocialController {
  // ===== POSTS =====

  createPost = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { content, mediaUrl, projectId } = req.body;

    if (!content) {
      return res.status(400).json({ error: 'content is required' });
    }

    const post = await socialService.createPost(req.userId, {
      content,
      mediaUrl,
      projectId
    });

    res.status(201).json({
      success: true,
      message: 'Post created',
      data: post
    });
  });

  getFeed = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;

    const result = await socialService.getFeed(req.userId, page, limit);

    res.json({
      success: true,
      data: result.posts,
      pagination: {
        page,
        limit,
        total: result.total,
        totalPages: Math.ceil(result.total / limit)
      }
    });
  });

  getUserPosts = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { userId } = req.params;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;

    const result = await socialService.getUserPosts(userId, page, limit);

    res.json({
      success: true,
      data: result.posts,
      pagination: {
        page,
        limit,
        total: result.total,
        totalPages: Math.ceil(result.total / limit)
      }
    });
  });

  deletePost = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { id } = req.params;

    await socialService.deletePost(id, req.userId);

    res.json({
      success: true,
      message: 'Post deleted'
    });
  });

  // ===== LIKES =====

  likePost = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { postId } = req.body;

    await socialService.likePost(postId, req.userId);

    res.json({
      success: true,
      message: 'Post liked'
    });
  });

  unlikePost = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { postId } = req.body;

    await socialService.unlikePost(postId, req.userId);

    res.json({
      success: true,
      message: 'Post unliked'
    });
  });

  // ===== COMMENTS =====

  addComment = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { postId, content } = req.body;

    if (!postId || !content) {
      return res.status(400).json({ error: 'postId and content are required' });
    }

    const comment = await socialService.addComment(postId, req.userId, content);

    res.status(201).json({
      success: true,
      message: 'Comment added',
      data: comment
    });
  });

  getComments = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { postId } = req.params;

    const comments = await socialService.getComments(postId);

    res.json({
      success: true,
      data: comments
    });
  });

  deleteComment = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { id } = req.params;

    await socialService.deleteComment(id, req.userId);

    res.json({
      success: true,
      message: 'Comment deleted'
    });
  });

  // ===== FOLLOW =====

  followUser = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { userId } = req.body;

    await socialService.followUser(req.userId, userId);

    res.json({
      success: true,
      message: 'User followed'
    });
  });

  unfollowUser = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { userId } = req.body;

    await socialService.unfollowUser(req.userId, userId);

    res.json({
      success: true,
      message: 'User unfollowed'
    });
  });

  getFollowers = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { userId } = req.params;

    const followers = await socialService.getFollowers(userId);

    res.json({
      success: true,
      data: followers
    });
  });

  getFollowing = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { userId } = req.params;

    const following = await socialService.getFollowing(userId);

    res.json({
      success: true,
      data: following
    });
  });

  checkFollowing = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { userId } = req.params;

    const isFollowing = await socialService.isFollowing(req.userId, userId);

    res.json({
      success: true,
      data: { isFollowing }
    });
  });

  // ===== NOTIFICATIONS =====

  getNotifications = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const unreadOnly = req.query.unreadOnly === 'true';

    const notifications = await socialService.getNotifications(req.userId, unreadOnly);

    res.json({
      success: true,
      data: notifications
    });
  });

  markAsRead = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { id } = req.params;

    await socialService.markAsRead(id, req.userId);

    res.json({
      success: true,
      message: 'Notification marked as read'
    });
  });

  markAllAsRead = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    await socialService.markAllAsRead(req.userId);

    res.json({
      success: true,
      message: 'All notifications marked as read'
    });
  });

  // ===== USER PROFILE =====

  updateProfile = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { username, bio, avatar } = req.body;

    const user = await socialService.updateProfile(req.userId, {
      username,
      bio,
      avatar
    });

    res.json({
      success: true,
      message: 'Profile updated',
      data: user
    });
  });

  getUserProfile = asyncHandler(async (req: AuthRequest, res: Response) => {
    const { userId } = req.params;

    const user = await socialService.getUserProfile(userId);

    res.json({
      success: true,
      data: user
    });
  });
}

export default new SocialController();
