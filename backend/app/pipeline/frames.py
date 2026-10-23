import subprocess
from pathlib import Path


def key_frame(video: Path, t: float, out: Path) -> Path | None:
    """JPEG of the frame at second t (clamped to the start); None if ffmpeg can't read it."""
    cmd = [
        "ffmpeg",
        "-y",
        "-loglevel",
        "error",
        "-ss",
        f"{max(t, 0):.2f}",
        "-i",
        str(video),
    ]
    cmd += ["-frames:v", "1", "-q:v", "3", str(out)]
    done = subprocess.run(cmd, check=False, capture_output=True, timeout=60)
    if done.returncode != 0 or not out.exists() or out.stat().st_size == 0:
        # Past the end of a short clip: fall back to the first frame.
        if t > 0:
            return key_frame(video, 0, out)
        return None
    return out
