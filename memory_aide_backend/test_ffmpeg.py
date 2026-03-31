import imageio_ffmpeg
import subprocess
import os

ffmpeg_path = imageio_ffmpeg.get_ffmpeg_exe()
print(f"FFmpeg path found: {ffmpeg_path}")

try:
    result = subprocess.run([ffmpeg_path, "-version"], capture_output=True, text=True)
    print(f"FFmpeg check result: {result.returncode}")
    if result.returncode == 0:
        print("FFmpeg is executable via imageio-ffmpeg.")
    else:
        print(f"FFmpeg failed with: {result.stderr}")
except Exception as e:
    print(f"Error executing ffmpeg: {e}")
