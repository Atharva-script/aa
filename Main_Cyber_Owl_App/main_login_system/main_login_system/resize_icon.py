from PIL import Image
import os

def process_icon():
    source_path = "assets/logo/logo_v2.png"
    dest_path = "windows/runner/resources/app_icon.ico"
    
    if not os.path.exists(source_path):
        print(f"Error: {source_path} not found.")
        return

    print("Opening source image...")
    img = Image.open(source_path)
    
    # ensure RGBA
    img = img.convert("RGBA")
    
    # Get bounding box of non-transparent part
    print("Cropping content...")
    bbox = img.getbbox()
    if bbox:
        img_cropped = img.crop(bbox)
    else:
        img_cropped = img
        
    # Create a square canvas
    w, h = img_cropped.size
    size = max(w, h)
    
    # Add a small padding (amount of pixels around)
    # Reduced padding to 0% to maximize visual size (full bleed)
    padding = 0
    new_size = size + (padding * 2)
    
    new_img = Image.new("RGBA", (new_size, new_size), (0, 0, 0, 0))
    
    # Paste centered
    start_x = (new_size - w) // 2
    start_y = (new_size - h) // 2
    new_img.paste(img_cropped, (start_x, start_y))
    
    # Resize to standard icon sizes for Windows
    # 256x256 is the standard large size
    final_img = new_img.resize((256, 256), Image.Resampling.LANCZOS)
    
    print("Saving to ICO...")
    # Saving with sizes argument ensures we create a proper multi-size ICO
    # typically 16, 32, 48, 64, 128, 256
    icon_sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)]
    final_img.save(dest_path, format='ICO', sizes=icon_sizes)
    print(f"Success! Created {dest_path}")

if __name__ == "__main__":
    process_icon()
