"""
Celery Tasks for Video Generation
==================================

Defines async Celery tasks for:
- Base video generation
- Video refinement/upscaling
- Batch processing
- Post-processing pipelines
"""

import os
import time
import asyncio
import logging
from typing import Dict, Any, Optional
from celery import Celery, Task
from celery.signals import task_prerun, task_postrun, task_failure
import torch

logger = logging.getLogger(__name__)

# Celery app (configured by queue.py)
celery = Celery("videogen")
celery.config_from_object("celeryconfig", silent=True)

# Output directory
OUTPUT_DIR = os.environ.get("VIDEO_OUTPUT_DIR", "/tmp/videogen/output")


class VideoGenerationTask(Task):
    """Base class for video generation tasks with shared resources"""

    _generator = None
    _refiner = None
    _queue = None

    @property
    def generator(self):
        """Lazy-load video generator"""
        if self._generator is None:
            from ..layer1_inference import WanVideoGenerator
            self._generator = WanVideoGenerator()
        return self._generator

    @property
    def refiner(self):
        """Lazy-load video refiner"""
        if self._refiner is None:
            from .refiner import VideoRefiner
            self._refiner = VideoRefiner()
        return self._refiner

    @property
    def queue(self):
        """Lazy-load task queue"""
        if self._queue is None:
            from .queue import TaskQueue
            self._queue = TaskQueue()
        return self._queue


def run_async(coro):
    """Run async coroutine in sync context"""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


@celery.task(
    bind=True,
    base=VideoGenerationTask,
    name="videogen.generate",
    queue="video_generation",
    max_retries=3,
    soft_time_limit=3500,
    time_limit=3600,
)
def generate_video_task(self, task_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Main video generation task.

    Args:
        task_data: VideoTask data dictionary

    Returns:
        Generation result dictionary
    """
    from .queue import VideoTask, TaskQueue
    from ..layer1_inference import GenerationConfig, PrecisionMode
    from ..layer3_genius import ResourceChecker, PromptExpander, VideoGenre

    task = VideoTask.from_dict(task_data)
    task_id = task.task_id
    start_time = time.time()

    logger.info(f"Starting generation task {task_id}")

    try:
        # Progress callback
        def update_progress(progress: float, stage: str, metadata: Optional[Dict] = None):
            run_async(self.queue.update_progress(task_id, progress, stage, metadata))
            self.update_state(state="PROGRESS", meta={
                "progress": progress,
                "stage": stage,
            })

        update_progress(0.0, "Initializing")

        # Auto-detect optimal config
        resource_checker = ResourceChecker()
        optimal_config = resource_checker.get_optimal_config(
            target_resolution=(task.width, task.height),
            target_duration=task.num_frames / task.fps,
            fps=task.fps,
        )

        update_progress(5.0, "Expanding prompt")

        # Expand prompt with genre-specific enhancements
        expander = PromptExpander()
        try:
            genre = VideoGenre(task.genre.lower())
        except ValueError:
            genre = VideoGenre.CINEMATIC

        expanded = run_async(expander.expand_prompt(
            prompt=task.prompt,
            genre=genre,
            duration_seconds=task.num_frames / task.fps,
        ))

        update_progress(10.0, "Loading model")

        # Determine precision
        precision_map = {
            "fp32": PrecisionMode.FP32,
            "fp16": PrecisionMode.FP16,
            "bf16": PrecisionMode.BF16,
            "nf4": PrecisionMode.NF4,
        }
        precision = precision_map.get(optimal_config.precision.value, PrecisionMode.FP16)

        # Load model
        run_async(self.generator.load_model(
            precision=precision,
            progress_callback=lambda p: update_progress(10 + p * 0.1, "Loading model"),
        ))

        update_progress(20.0, "Generating video")

        # Configure generation
        config = GenerationConfig(
            prompt=expanded.enhanced_prompt,
            negative_prompt=expanded.negative_prompt or task.negative_prompt,
            width=task.width,
            height=task.height,
            num_frames=min(task.num_frames, optimal_config.max_frames),
            fps=task.fps,
            seed=task.seed,
            guidance_scale=task.guidance_scale,
            num_inference_steps=task.num_inference_steps,
            use_tea_cache=optimal_config.use_tea_cache,
            tea_cache_threshold=0.1,
            use_tiled_vae=optimal_config.use_tiled_vae,
            tile_size=optimal_config.tile_size,
            enable_cpu_offload=optimal_config.enable_cpu_offload,
        )

        # Generate base video
        result = run_async(self.generator.generate(
            config=config,
            progress_callback=lambda p: update_progress(20 + p * 0.5, "Generating frames"),
        ))

        if not result.success:
            raise Exception(result.error_message or "Generation failed")

        base_output_path = result.output_path
        update_progress(70.0, "Base generation complete")

        # Refinement phase
        final_output_path = base_output_path
        if task.enable_refine and task.target_resolution[0] > task.width:
            update_progress(75.0, "Upscaling to target resolution")

            from .refiner import RefineConfig
            refine_config = RefineConfig(
                input_path=base_output_path,
                output_path=os.path.join(OUTPUT_DIR, f"{task_id}_refined.mp4"),
                target_resolution=task.target_resolution,
                enable_pyramid_flow=True,
                enable_face_consistency=True,
                ffmpeg_grain=0.3,
                ffmpeg_sharpness=0.5,
            )

            refine_result = run_async(self.refiner.refine(
                config=refine_config,
                progress_callback=lambda p: update_progress(75 + p * 0.2, "Refining video"),
            ))

            if refine_result.success:
                final_output_path = refine_result.output_path
                update_progress(95.0, "Refinement complete")

        # Generate thumbnail
        update_progress(97.0, "Generating thumbnail")
        thumbnail_path = os.path.join(OUTPUT_DIR, f"{task_id}_thumb.jpg")
        _generate_thumbnail(final_output_path, thumbnail_path)

        # Complete task
        generation_time = time.time() - start_time
        run_async(self.queue.complete_task(
            task_id=task_id,
            output_path=final_output_path,
            thumbnail_path=thumbnail_path,
            duration_seconds=task.num_frames / task.fps,
            generation_time_seconds=generation_time,
            metadata={
                "precision": precision.value,
                "frames": task.num_frames,
                "resolution": f"{task.width}x{task.height}",
                "genre": task.genre,
                "expanded_prompt": expanded.enhanced_prompt,
            },
        ))

        update_progress(100.0, "Complete")

        logger.info(f"Task {task_id} completed in {generation_time:.1f}s")

        return {
            "task_id": task_id,
            "success": True,
            "output_path": final_output_path,
            "thumbnail_path": thumbnail_path,
            "generation_time": generation_time,
        }

    except Exception as e:
        logger.exception(f"Task {task_id} failed: {e}")
        run_async(self.queue.fail_task(
            task_id=task_id,
            error_message=str(e),
            retry=self.request.retries < self.max_retries,
        ))
        raise


@celery.task(
    bind=True,
    base=VideoGenerationTask,
    name="videogen.refine",
    queue="video_refinement",
    max_retries=2,
    soft_time_limit=1800,
    time_limit=2000,
)
def refine_video_task(
    self,
    input_path: str,
    output_path: str,
    target_resolution: tuple = (1920, 1080),
    options: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Standalone video refinement task.

    Args:
        input_path: Path to input video
        output_path: Path for output video
        target_resolution: Target (width, height)
        options: Additional refinement options

    Returns:
        Refinement result dictionary
    """
    from .refiner import RefineConfig

    options = options or {}
    task_id = self.request.id
    start_time = time.time()

    logger.info(f"Starting refinement task {task_id}")

    try:
        def update_progress(progress: float, stage: str):
            self.update_state(state="PROGRESS", meta={
                "progress": progress,
                "stage": stage,
            })

        update_progress(0.0, "Initializing refiner")

        config = RefineConfig(
            input_path=input_path,
            output_path=output_path,
            target_resolution=target_resolution,
            enable_pyramid_flow=options.get("pyramid_flow", True),
            enable_face_consistency=options.get("face_consistency", True),
            motion_bucket_id=options.get("motion_bucket", 127),
            ffmpeg_grain=options.get("grain", 0.3),
            ffmpeg_sharpness=options.get("sharpness", 0.5),
        )

        result = run_async(self.refiner.refine(
            config=config,
            progress_callback=lambda p: update_progress(p, "Refining"),
        ))

        if not result.success:
            raise Exception(result.error_message or "Refinement failed")

        generation_time = time.time() - start_time
        logger.info(f"Refinement {task_id} completed in {generation_time:.1f}s")

        return {
            "task_id": task_id,
            "success": True,
            "output_path": result.output_path,
            "generation_time": generation_time,
        }

    except Exception as e:
        logger.exception(f"Refinement {task_id} failed: {e}")
        raise


@celery.task(
    bind=True,
    base=VideoGenerationTask,
    name="videogen.batch",
    queue="video_generation",
    soft_time_limit=14400,  # 4 hours
    time_limit=14500,
)
def batch_generate_task(
    self,
    tasks: list,
    parallel: int = 1,
) -> Dict[str, Any]:
    """
    Batch video generation task.

    Args:
        tasks: List of VideoTask data dictionaries
        parallel: Number of parallel generations (limited by VRAM)

    Returns:
        Batch result summary
    """
    from .queue import VideoTask

    batch_id = self.request.id
    results = []
    start_time = time.time()

    logger.info(f"Starting batch {batch_id} with {len(tasks)} tasks")

    for i, task_data in enumerate(tasks):
        try:
            task = VideoTask.from_dict(task_data)
            result = generate_video_task.apply(args=[task_data])
            results.append({
                "task_id": task.task_id,
                "success": result.get("success", False),
                "output_path": result.get("output_path"),
            })

            self.update_state(state="PROGRESS", meta={
                "completed": i + 1,
                "total": len(tasks),
                "progress": (i + 1) / len(tasks) * 100,
            })

        except Exception as e:
            logger.error(f"Batch task {i} failed: {e}")
            results.append({
                "task_id": task_data.get("task_id"),
                "success": False,
                "error": str(e),
            })

    generation_time = time.time() - start_time
    successful = sum(1 for r in results if r.get("success"))

    logger.info(f"Batch {batch_id} completed: {successful}/{len(tasks)} successful")

    return {
        "batch_id": batch_id,
        "total": len(tasks),
        "successful": successful,
        "failed": len(tasks) - successful,
        "results": results,
        "generation_time": generation_time,
    }


def _generate_thumbnail(video_path: str, output_path: str, frame_number: int = 0):
    """Generate thumbnail from video frame"""
    import subprocess

    try:
        subprocess.run([
            "ffmpeg", "-y",
            "-i", video_path,
            "-vf", f"select=eq(n\\,{frame_number})",
            "-frames:v", "1",
            "-q:v", "2",
            output_path,
        ], capture_output=True, check=True)
    except subprocess.CalledProcessError as e:
        logger.warning(f"Thumbnail generation failed: {e}")


# Celery signals for monitoring
@task_prerun.connect
def task_prerun_handler(task_id, task, args, kwargs, **kw):
    """Log task start"""
    logger.info(f"Task {task_id} starting: {task.name}")


@task_postrun.connect
def task_postrun_handler(task_id, task, args, kwargs, retval, state, **kw):
    """Log task completion and cleanup GPU memory"""
    logger.info(f"Task {task_id} finished with state {state}")

    # Clear GPU cache
    if torch.cuda.is_available():
        torch.cuda.empty_cache()


@task_failure.connect
def task_failure_handler(task_id, exception, args, kwargs, traceback, einfo, **kw):
    """Handle task failures"""
    logger.error(f"Task {task_id} failed: {exception}")

    # Clear GPU cache on failure
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
