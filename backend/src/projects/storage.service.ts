// Cloud Storage Service (S3 / Cloudflare R2)
import AWS from 'aws-sdk';
import { AppError } from '../middleware/error.middleware';

// Configure AWS SDK (works with both S3 and Cloudflare R2)
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION || 'eu-central-1',
  ...(process.env.S3_ENDPOINT && {
    endpoint: process.env.S3_ENDPOINT, // For Cloudflare R2
    s3ForcePathStyle: true
  })
});

const BUCKET_NAME = process.env.S3_BUCKET_NAME || 'echoelmusic-projects';

export interface UploadResult {
  url: string;
  key: string;
  size: number;
}

export class StorageService {
  /**
   * Upload file to S3/R2
   */
  async uploadFile(
    file: Buffer,
    fileName: string,
    userId: string,
    contentType: string = 'application/octet-stream'
  ): Promise<UploadResult> {
    const key = `users/${userId}/${Date.now()}-${fileName}`;

    try {
      const result = await s3.upload({
        Bucket: BUCKET_NAME,
        Key: key,
        Body: file,
        ContentType: contentType,
        ACL: 'private' // Files are private, accessed via signed URLs
      }).promise();

      return {
        url: result.Location,
        key: result.Key,
        size: file.length
      };
    } catch (error) {
      console.error('S3 Upload Error:', error);
      throw new AppError('Failed to upload file to cloud storage', 500);
    }
  }

  /**
   * Get signed URL for downloading file
   */
  async getSignedUrl(key: string, expiresIn: number = 3600): Promise<string> {
    try {
      return s3.getSignedUrl('getObject', {
        Bucket: BUCKET_NAME,
        Key: key,
        Expires: expiresIn // URL expires in 1 hour by default
      });
    } catch (error) {
      console.error('S3 Signed URL Error:', error);
      throw new AppError('Failed to generate download URL', 500);
    }
  }

  /**
   * Delete file from S3/R2
   */
  async deleteFile(key: string): Promise<void> {
    try {
      await s3.deleteObject({
        Bucket: BUCKET_NAME,
        Key: key
      }).promise();
    } catch (error) {
      console.error('S3 Delete Error:', error);
      throw new AppError('Failed to delete file from cloud storage', 500);
    }
  }

  /**
   * Delete multiple files
   */
  async deleteFiles(keys: string[]): Promise<void> {
    if (keys.length === 0) return;

    try {
      await s3.deleteObjects({
        Bucket: BUCKET_NAME,
        Delete: {
          Objects: keys.map(key => ({ Key: key }))
        }
      }).promise();
    } catch (error) {
      console.error('S3 Batch Delete Error:', error);
      throw new AppError('Failed to delete files from cloud storage', 500);
    }
  }
}

export default new StorageService();
