// Social Features Service
import { PrismaClient } from '@prisma/client';
import { AppError } from '../middleware/error.middleware';

const prisma = new PrismaClient();

export interface CreatePostInput {
  content: string;
  mediaUrl?: string;
  projectId?: string;
}

export class SocialService {
  // ===== POSTS =====

  /**
   * Create post
   */
  async createPost(userId: string, input: CreatePostInput): Promise<any> {
    return prisma.post.create({
      data: {
        userId,
        content: input.content,
        mediaUrl: input.mediaUrl,
        projectId: input.projectId
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            username: true,
            avatar: true
          }
        },
        project: {
          select: {
            id: true,
            title: true
          }
        }
      }
    });
  }

  /**
   * Get feed (posts from followed users)
   */
  async getFeed(
    userId: string,
    page: number = 1,
    limit: number = 20
  ): Promise<{ posts: any[]; total: number }> {
    const skip = (page - 1) * limit;

    // Get users that current user follows
    const following = await prisma.follow.findMany({
      where: { followerId: userId },
      select: { followingId: true }
    });

    const followingIds = following.map(f => f.followingId);
    followingIds.push(userId); // Include own posts

    const [posts, total] = await Promise.all([
      prisma.post.findMany({
        where: {
          userId: { in: followingIds }
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          user: {
            select: {
              id: true,
              name: true,
              username: true,
              avatar: true
            }
          },
          project: {
            select: {
              id: true,
              title: true
            }
          },
          _count: {
            select: {
              likes: true,
              comments: true
            }
          }
        }
      }),
      prisma.post.count({
        where: {
          userId: { in: followingIds }
        }
      })
    ]);

    return { posts, total };
  }

  /**
   * Get user's posts
   */
  async getUserPosts(
    targetUserId: string,
    page: number = 1,
    limit: number = 20
  ): Promise<{ posts: any[]; total: number }> {
    const skip = (page - 1) * limit;

    const [posts, total] = await Promise.all([
      prisma.post.findMany({
        where: { userId: targetUserId },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          user: {
            select: {
              id: true,
              name: true,
              username: true,
              avatar: true
            }
          },
          _count: {
            select: {
              likes: true,
              comments: true
            }
          }
        }
      }),
      prisma.post.count({ where: { userId: targetUserId } })
    ]);

    return { posts, total };
  }

  /**
   * Delete post
   */
  async deletePost(postId: string, userId: string): Promise<void> {
    const post = await prisma.post.findUnique({ where: { id: postId } });
    if (!post) {
      throw new AppError('Post not found', 404);
    }

    if (post.userId !== userId) {
      throw new AppError('Unauthorized', 403);
    }

    await prisma.post.delete({ where: { id: postId } });
  }

  // ===== LIKES =====

  /**
   * Like post
   */
  async likePost(postId: string, userId: string): Promise<void> {
    // Check if already liked
    const existingLike = await prisma.like.findUnique({
      where: {
        postId_userId: { postId, userId }
      }
    });

    if (existingLike) {
      throw new AppError('Already liked', 400);
    }

    // Create like
    await prisma.like.create({
      data: { postId, userId }
    });

    // Increment likes count
    await prisma.post.update({
      where: { id: postId },
      data: { likesCount: { increment: 1 } }
    });

    // Create notification
    const post = await prisma.post.findUnique({ where: { id: postId } });
    if (post && post.userId !== userId) {
      await this.createNotification({
        userId: post.userId,
        type: 'LIKE',
        title: 'New like',
        message: 'Someone liked your post',
        linkUrl: `/posts/${postId}`
      });
    }
  }

  /**
   * Unlike post
   */
  async unlikePost(postId: string, userId: string): Promise<void> {
    const like = await prisma.like.findUnique({
      where: {
        postId_userId: { postId, userId }
      }
    });

    if (!like) {
      throw new AppError('Not liked', 400);
    }

    await prisma.like.delete({
      where: { id: like.id }
    });

    await prisma.post.update({
      where: { id: postId },
      data: { likesCount: { decrement: 1 } }
    });
  }

  // ===== COMMENTS =====

  /**
   * Add comment
   */
  async addComment(
    postId: string,
    userId: string,
    content: string
  ): Promise<any> {
    const comment = await prisma.comment.create({
      data: {
        postId,
        userId,
        content
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            username: true,
            avatar: true
          }
        }
      }
    });

    // Increment comments count
    await prisma.post.update({
      where: { id: postId },
      data: { commentsCount: { increment: 1 } }
    });

    // Create notification
    const post = await prisma.post.findUnique({ where: { id: postId } });
    if (post && post.userId !== userId) {
      await this.createNotification({
        userId: post.userId,
        type: 'COMMENT',
        title: 'New comment',
        message: 'Someone commented on your post',
        linkUrl: `/posts/${postId}`
      });
    }

    return comment;
  }

  /**
   * Get comments for post
   */
  async getComments(postId: string): Promise<any[]> {
    return prisma.comment.findMany({
      where: { postId },
      orderBy: { createdAt: 'asc' },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            username: true,
            avatar: true
          }
        }
      }
    });
  }

  /**
   * Delete comment
   */
  async deleteComment(commentId: string, userId: string): Promise<void> {
    const comment = await prisma.comment.findUnique({ where: { id: commentId } });
    if (!comment) {
      throw new AppError('Comment not found', 404);
    }

    if (comment.userId !== userId) {
      throw new AppError('Unauthorized', 403);
    }

    await prisma.comment.delete({ where: { id: commentId } });

    await prisma.post.update({
      where: { id: comment.postId },
      data: { commentsCount: { decrement: 1 } }
    });
  }

  // ===== FOLLOW =====

  /**
   * Follow user
   */
  async followUser(followerId: string, followingId: string): Promise<void> {
    if (followerId === followingId) {
      throw new AppError('Cannot follow yourself', 400);
    }

    // Check if already following
    const existingFollow = await prisma.follow.findUnique({
      where: {
        followerId_followingId: { followerId, followingId }
      }
    });

    if (existingFollow) {
      throw new AppError('Already following', 400);
    }

    await prisma.follow.create({
      data: { followerId, followingId }
    });

    // Create notification
    await this.createNotification({
      userId: followingId,
      type: 'FOLLOW',
      title: 'New follower',
      message: 'Someone started following you',
      linkUrl: `/users/${followerId}`
    });
  }

  /**
   * Unfollow user
   */
  async unfollowUser(followerId: string, followingId: string): Promise<void> {
    const follow = await prisma.follow.findUnique({
      where: {
        followerId_followingId: { followerId, followingId }
      }
    });

    if (!follow) {
      throw new AppError('Not following', 400);
    }

    await prisma.follow.delete({ where: { id: follow.id } });
  }

  /**
   * Get followers
   */
  async getFollowers(userId: string): Promise<any[]> {
    const followers = await prisma.follow.findMany({
      where: { followingId: userId },
      include: {
        follower: {
          select: {
            id: true,
            name: true,
            username: true,
            avatar: true,
            bio: true
          }
        }
      }
    });

    return followers.map(f => f.follower);
  }

  /**
   * Get following
   */
  async getFollowing(userId: string): Promise<any[]> {
    const following = await prisma.follow.findMany({
      where: { followerId: userId },
      include: {
        following: {
          select: {
            id: true,
            name: true,
            username: true,
            avatar: true,
            bio: true
          }
        }
      }
    });

    return following.map(f => f.following);
  }

  /**
   * Check if following
   */
  async isFollowing(followerId: string, followingId: string): Promise<boolean> {
    const follow = await prisma.follow.findUnique({
      where: {
        followerId_followingId: { followerId, followingId }
      }
    });

    return !!follow;
  }

  // ===== NOTIFICATIONS =====

  /**
   * Create notification
   */
  async createNotification(data: {
    userId: string;
    type: 'FOLLOW' | 'LIKE' | 'COMMENT' | 'NFT_SALE' | 'RELEASE_LIVE' | 'STREAM_STARTED' | 'PAYMENT_RECEIVED';
    title: string;
    message: string;
    linkUrl?: string;
  }): Promise<void> {
    await prisma.notification.create({
      data
    });
  }

  /**
   * Get notifications
   */
  async getNotifications(
    userId: string,
    unreadOnly: boolean = false
  ): Promise<any[]> {
    const where: any = { userId };
    if (unreadOnly) {
      where.read = false;
    }

    return prisma.notification.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 50
    });
  }

  /**
   * Mark notification as read
   */
  async markAsRead(notificationId: string, userId: string): Promise<void> {
    const notification = await prisma.notification.findUnique({
      where: { id: notificationId }
    });

    if (!notification || notification.userId !== userId) {
      throw new AppError('Notification not found', 404);
    }

    await prisma.notification.update({
      where: { id: notificationId },
      data: { read: true }
    });
  }

  /**
   * Mark all notifications as read
   */
  async markAllAsRead(userId: string): Promise<void> {
    await prisma.notification.updateMany({
      where: { userId, read: false },
      data: { read: true }
    });
  }

  // ===== USER PROFILE =====

  /**
   * Update user profile
   */
  async updateProfile(
    userId: string,
    data: {
      username?: string;
      bio?: string;
      avatar?: string;
    }
  ): Promise<any> {
    // Check username uniqueness
    if (data.username) {
      const existing = await prisma.user.findUnique({
        where: { username: data.username }
      });

      if (existing && existing.id !== userId) {
        throw new AppError('Username already taken', 400);
      }
    }

    return prisma.user.update({
      where: { id: userId },
      data,
      select: {
        id: true,
        email: true,
        name: true,
        username: true,
        bio: true,
        avatar: true
      }
    });
  }

  /**
   * Get user profile with stats
   */
  async getUserProfile(userId: string): Promise<any> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        username: true,
        bio: true,
        avatar: true,
        createdAt: true,
        _count: {
          select: {
            posts: true,
            followers: true,
            following: true
          }
        }
      }
    });

    if (!user) {
      throw new AppError('User not found', 404);
    }

    return user;
  }
}

export default new SocialService();
