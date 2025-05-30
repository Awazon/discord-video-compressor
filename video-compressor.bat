@python -x "%~f0" %* & exit /b %errorlevel%
# -*- coding: utf-8 -*-
import sys
import os
import subprocess

# --- Settings (modify as needed) ---
H264_PRESET = "medium"  # H.264 preset (e.g., medium, fast, veryfast)
MIN_VIDEO_BITRATE_KBPS = 100  # Minimum video bitrate to use (kbps)
ASSUMED_AUDIO_BITRATE_KBPS = 128 # Assumed audio bitrate for video bitrate calculation (kbps)

def get_user_target_size_mb():
    while True:
        try:
            size_str = input(f"Enter target size per file in MB (e.g., 50): ")
            target_mb = float(size_str)
            if target_mb <= 0:
                print("[ERROR] Target size must be a positive number.")
                continue
            return target_mb
        except ValueError:
            print("[ERROR] Invalid input. Please enter a number.")
        except EOFError:
            return None

def get_video_duration_seconds(file_path):
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        file_path
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, encoding='utf-8', errors='ignore')
        return float(result.stdout.strip())
    except FileNotFoundError:
        print(f"[ERROR] ffprobe not found. Ensure FFmpeg/ffprobe is in PATH.")
        return None
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] ffprobe failed for {os.path.basename(file_path)}: {e.stderr}")
        return None
    except ValueError:
        print(f"[ERROR] Could not parse duration for {os.path.basename(file_path)}.")
        return None

def calculate_video_bitrate_kbps(target_size_bytes, duration_seconds):
    video_target_bytes = target_size_bytes - ((ASSUMED_AUDIO_BITRATE_KBPS * 1000 / 8) * duration_seconds)
    if video_target_bytes <= 0:
        print(f"[WARNING] Target size too small for estimated audio. Video bitrate will be minimal.")
        return MIN_VIDEO_BITRATE_KBPS

    video_bitrate_kbps = (video_target_bytes * 8) / duration_seconds / 1000
    
    if video_bitrate_kbps < MIN_VIDEO_BITRATE_KBPS:
        return MIN_VIDEO_BITRATE_KBPS
    return video_bitrate_kbps

def compress_video_h264(input_path, output_path, target_size_mb):
    print(f"\nProcessing: {os.path.basename(input_path)} -> Target ~{target_size_mb:.1f} MB")

    duration = get_video_duration_seconds(input_path)
    if duration is None:
        return False

    target_size_bytes = target_size_mb * 1024 * 1024
    video_bitrate_kbps = calculate_video_bitrate_kbps(target_size_bytes, duration)
    
    pass_log_prefix = os.path.join(os.path.dirname(input_path), f"{os.path.splitext(os.path.basename(input_path))[0]}_ffmpeg_passlog")
    
    log_files_to_delete = [
        f"{pass_log_prefix}-0.log",
        f"{pass_log_prefix}-0.log.mbtree"
    ]

    ffmpeg_cmd_base = ["ffmpeg", "-y", "-nostdin", "-i", input_path]
    ffmpeg_cmd_video = [
        "-c:v", "libx264",
        "-b:v", f"{video_bitrate_kbps:.0f}k",
        "-preset", H264_PRESET,
        "-passlogfile", pass_log_prefix
    ]

    cmd1 = ffmpeg_cmd_base + ffmpeg_cmd_video + ["-pass", "1", "-an", "-f", "mp4", "NUL" if os.name == 'nt' else "/dev/null"]
    cmd2 = ffmpeg_cmd_base + ffmpeg_cmd_video + ["-pass", "2", "-c:a", "copy", output_path]

    compression_successful = False
    try:
        print(f"  1st Pass (H.264, Preset: {H264_PRESET}, Target Video Bitrate: {video_bitrate_kbps:.0f} kbps)...")
        subprocess.run(cmd1, check=True, capture_output=True, text=True, encoding='utf-8', errors='ignore')
        
        print(f"  2nd Pass...")
        subprocess.run(cmd2, check=True, capture_output=True, text=True, encoding='utf-8', errors='ignore')
        
        final_size_mb = os.path.getsize(output_path) / (1024 * 1024) if os.path.exists(output_path) else 0
        print(f"[SUCCESS] Compressed {os.path.basename(output_path)} ({final_size_mb:.2f} MB)")
        compression_successful = True
    except FileNotFoundError:
        print(f"[ERROR] ffmpeg command not found. Ensure FFmpeg is in your system's PATH.")
        sys.exit(1) 
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] FFmpeg failed for {os.path.basename(input_path)}.")
        if e.stderr:
            print("--- FFmpeg Error Output (last 5 lines) ---")
            for line in e.stderr.splitlines()[-5:]:
                 print(line)
            print("------------------------------------------")
        if os.path.exists(output_path):
            try: os.remove(output_path)
            except OSError: pass
    except Exception as e_gen:
        print(f"[ERROR] An unexpected error occurred with {os.path.basename(input_path)}: {e_gen}")
    finally:
        for log_file in log_files_to_delete:
            if os.path.exists(log_file):
                try:
                    os.remove(log_file)
                except OSError as err:
                    print(f"[WARNING] Could not delete passlog file {log_file}: {err}")
    
    return compression_successful

def main():
    print("--- Simple H.264 Video Compressor ---")
    if len(sys.argv) < 2:
        print("Usage: Drag & drop video files onto this script, or run as:")
        print(f"  {os.path.basename(sys.argv[0])} file1.mp4 file2.mov ...")
        input("Press Enter to exit.")
        return

    input_files = sys.argv[1:]
    target_mb = get_user_target_size_mb()

    if target_mb is None:
        print("No target size entered. Exiting.")
        return

    print(f"\nTargeting approx. {target_mb:.1f} MB per file. Output files will overwrite existing ones.")
    
    success_count = 0
    fail_count = 0

    for file_path in input_files:
        if not os.path.isfile(file_path):
            print(f"\nSkipping (not a file): {file_path}")
            fail_count += 1
            continue

        base, ext = os.path.splitext(os.path.basename(file_path))
        size_tag = str(int(target_mb)) if target_mb.is_integer() else f"{target_mb:.1f}"
        output_filename = f"{base}_{size_tag}MB_h264{ext}"
        output_filepath = os.path.join(os.path.dirname(file_path), output_filename)
        
        if compress_video_h264(file_path, output_filepath, target_mb):
            success_count += 1
        else:
            fail_count += 1
            
    print("\n--- Processing Complete ---")
    print(f"Successfully compressed: {success_count}")
    print(f"Failed or skipped: {fail_count}")
    input("Press Enter to exit.")

if __name__ == "__main__":
    main()
