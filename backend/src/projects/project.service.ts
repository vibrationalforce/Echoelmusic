// Project Service
import { PrismaClient, Project } from '@prisma/client';
import { AppError } from '../middleware/error.middleware';
import storageService from './storage.service';

const prisma = new PrismaClient();

export interface CreateProjectInput {
  title: string;
  description?: string;
  tempo?: number;
  platform?: 'DESKTOP' | 'IOS' | 'WEB';
}

export interface UploadProjectData {
  xmlData: string;
  audioFiles?: Array<{
    filename: string;
    buffer: Buffer;
    size: number;
    duration?: number;
    format: string;
  }>;
}

export class ProjectService {
  /**
   * Create new project
   */
  async createProject(
    userId: string,
    input: CreateProjectInput
  ): Promise<Project> {
    // Check user's project limit based on subscription
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new AppError('User not found', 404);
    }

    const projectCount = await prisma.project.count({ where: { userId } });

    // Free tier: max 5 projects
    if (user.subscription === 'FREE' && projectCount >= 5) {
      throw new AppError('Free tier limited to 5 projects. Upgrade to Pro for unlimited.', 403);
    }

    return prisma.project.create({
      data: {
        userId,
        title: input.title,
        description: input.description,
        tempo: input.tempo || 120.0,
        platform: input.platform || 'DESKTOP'
      }
    });
  }

  /**
   * Upload project data (XML + audio files)
   */
  async uploadProjectData(
    projectId: string,
    userId: string,
    data: UploadProjectData
  ): Promise<Project> {
    const project = await prisma.project.findUnique({
      where: { id: projectId }
    });

    if (!project) {
      throw new AppError('Project not found', 404);
    }

    if (project.userId !== userId) {
      throw new AppError('Unauthorized', 403);
    }

    // Upload XML data
    const xmlBuffer = Buffer.from(data.xmlData, 'utf-8');
    const xmlUpload = await storageService.uploadFile(
      xmlBuffer,
      `${project.title}.xml`,
      userId,
      'application/xml'
    );

    // Upload audio files
    const audioFileRecords = [];
    if (data.audioFiles && data.audioFiles.length > 0) {
      for (const audioFile of data.audioFiles) {
        const audioUpload = await storageService.uploadFile(
          audioFile.buffer,
          audioFile.filename,
          userId,
          `audio/${audioFile.format}`
        );

        audioFileRecords.push({
          projectId,
          filename: audioFile.filename,
          s3Url: audioUpload.url,
          size: audioFile.size,
          duration: audioFile.duration,
          format: audioFile.format
        });
      }
    }

    // Update project and create audio file records
    const updatedProject = await prisma.project.update({
      where: { id: projectId },
      data: {
        xmlDataUrl: xmlUpload.url,
        version: project.version + 1,
        audioFiles: {
          create: audioFileRecords
        }
      },
      include: {
        audioFiles: true
      }
    });

    return updatedProject;
  }

  /**
   * Get user's projects
   */
  async getUserProjects(
    userId: string,
    page: number = 1,
    limit: number = 20
  ): Promise<{ projects: Project[]; total: number }> {
    const skip = (page - 1) * limit;

    const [projects, total] = await Promise.all([
      prisma.project.findMany({
        where: { userId },
        include: {
          audioFiles: true
        },
        orderBy: { updatedAt: 'desc' },
        skip,
        take: limit
      }),
      prisma.project.count({ where: { userId } })
    ]);

    return { projects, total };
  }

  /**
   * Get project by ID with download URLs
   */
  async getProjectById(
    projectId: string,
    userId: string
  ): Promise<Project & { downloadUrls?: { xml?: string; audioFiles: any[] } }> {
    const project = await prisma.project.findUnique({
      where: { id: projectId },
      include: {
        audioFiles: true
      }
    });

    if (!project) {
      throw new AppError('Project not found', 404);
    }

    if (project.userId !== userId) {
      throw new AppError('Unauthorized', 403);
    }

    // Generate signed download URLs
    const downloadUrls: any = {
      audioFiles: []
    };

    if (project.xmlDataUrl) {
      // Extract S3 key from URL
      const xmlKey = this.extractS3Key(project.xmlDataUrl);
      if (xmlKey) {
        downloadUrls.xml = await storageService.getSignedUrl(xmlKey);
      }
    }

    for (const audioFile of project.audioFiles) {
      const audioKey = this.extractS3Key(audioFile.s3Url);
      if (audioKey) {
        downloadUrls.audioFiles.push({
          id: audioFile.id,
          filename: audioFile.filename,
          url: await storageService.getSignedUrl(audioKey),
          size: audioFile.size,
          duration: audioFile.duration,
          format: audioFile.format
        });
      }
    }

    return { ...project, downloadUrls };
  }

  /**
   * Delete project
   */
  async deleteProject(projectId: string, userId: string): Promise<void> {
    const project = await prisma.project.findUnique({
      where: { id: projectId },
      include: { audioFiles: true }
    });

    if (!project) {
      throw new AppError('Project not found', 404);
    }

    if (project.userId !== userId) {
      throw new AppError('Unauthorized', 403);
    }

    // Delete files from S3
    const keysToDelete: string[] = [];

    if (project.xmlDataUrl) {
      const xmlKey = this.extractS3Key(project.xmlDataUrl);
      if (xmlKey) keysToDelete.push(xmlKey);
    }

    for (const audioFile of project.audioFiles) {
      const audioKey = this.extractS3Key(audioFile.s3Url);
      if (audioKey) keysToDelete.push(audioKey);
    }

    if (keysToDelete.length > 0) {
      await storageService.deleteFiles(keysToDelete);
    }

    // Delete project from database (cascade deletes audio files)
    await prisma.project.delete({ where: { id: projectId } });
  }

  /**
   * Extract S3 key from URL
   */
  private extractS3Key(url: string): string | null {
    try {
      const urlObj = new URL(url);
      return urlObj.pathname.substring(1); // Remove leading slash
    } catch {
      return null;
    }
  }
}

export default new ProjectService();
