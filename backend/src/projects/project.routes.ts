// Project Routes
import { Router } from 'express';
import projectController from './project.controller';
import { authenticateToken } from '../middleware/auth.middleware';

const router = Router();

// All project routes require authentication
router.use(authenticateToken);

/**
 * @route   POST /api/projects
 * @desc    Create new project
 * @access  Private
 */
router.post('/', projectController.createProject);

/**
 * @route   POST /api/projects/upload
 * @desc    Upload project data (XML + audio files)
 * @access  Private
 */
router.post('/upload', projectController.uploadProject);

/**
 * @route   GET /api/projects
 * @desc    Get user's projects
 * @access  Private
 */
router.get('/', projectController.getUserProjects);

/**
 * @route   GET /api/projects/:id
 * @desc    Get project by ID with download URLs
 * @access  Private
 */
router.get('/:id', projectController.getProjectById);

/**
 * @route   DELETE /api/projects/:id
 * @desc    Delete project
 * @access  Private
 */
router.delete('/:id', projectController.deleteProject);

export default router;
