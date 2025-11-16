// Project Controller
import { Response, NextFunction } from 'express';
import { asyncHandler } from '../middleware/error.middleware';
import { AuthRequest } from '../middleware/auth.middleware';
import projectService from './project.service';
import multer from 'multer';

// Configure multer for file uploads (in-memory storage)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 100 * 1024 * 1024 // 100MB max file size
  }
});

export class ProjectController {
  /**
   * Create new project
   */
  createProject = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const project = await projectService.createProject(req.userId, req.body);

    res.status(201).json({
      success: true,
      message: 'Project created successfully',
      data: project
    });
  });

  /**
   * Upload project data
   */
  uploadProject = [
    upload.array('audioFiles', 50), // Max 50 audio files
    asyncHandler(async (req: AuthRequest, res: Response) => {
      if (!req.userId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const { projectId, xmlData } = req.body;
      const files = req.files as Express.Multer.File[];

      if (!projectId || !xmlData) {
        return res.status(400).json({ error: 'projectId and xmlData are required' });
      }

      // Process audio files
      const audioFiles = files?.map(file => ({
        filename: file.originalname,
        buffer: file.buffer,
        size: file.size,
        format: file.mimetype.split('/')[1] || 'wav'
      })) || [];

      const project = await projectService.uploadProjectData(
        projectId,
        req.userId,
        { xmlData, audioFiles }
      );

      res.json({
        success: true,
        message: 'Project uploaded successfully',
        data: project
      });
    })
  ];

  /**
   * Get user's projects
   */
  getUserProjects = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;

    const result = await projectService.getUserProjects(req.userId, page, limit);

    res.json({
      success: true,
      data: result.projects,
      pagination: {
        page,
        limit,
        total: result.total,
        totalPages: Math.ceil(result.total / limit)
      }
    });
  });

  /**
   * Get project by ID
   */
  getProjectById = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { id } = req.params;

    const project = await projectService.getProjectById(id, req.userId);

    res.json({
      success: true,
      data: project
    });
  });

  /**
   * Delete project
   */
  deleteProject = asyncHandler(async (req: AuthRequest, res: Response) => {
    if (!req.userId) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { id } = req.params;

    await projectService.deleteProject(id, req.userId);

    res.json({
      success: true,
      message: 'Project deleted successfully'
    });
  });
}

export default new ProjectController();
