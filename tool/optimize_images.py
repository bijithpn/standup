import os
import glob
try:
    from PIL import Image
except ImportError:
    print("Pillow is not installed")
    exit(1)

slideshow_dir = "assets/slideshow"
for img_path in glob.glob(f"{slideshow_dir}/*.png"):
    try:
        with Image.open(img_path) as img:
            # We convert to RGB to allow saving as JPEG
            if img.mode != 'RGB':
                img = img.convert('RGB')
            # Save as optimized JPEG
            jpg_path = img_path.replace('.png', '.jpeg')
            img.save(jpg_path, 'JPEG', optimize=True, quality=80)
            print(f"Optimized {img_path} -> {jpg_path}")
        
        # Remove the original PNG
        os.remove(img_path)
    except Exception as e:
        print(f"Error processing {img_path}: {e}")
