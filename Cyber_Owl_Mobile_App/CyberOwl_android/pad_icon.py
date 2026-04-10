from PIL import Image
import os

def pad_image(input_path, output_path, padding_factor=0.3, shift_x_factor=0.0):
    img = Image.open(input_path).convert("RGBA")
    width, height = img.size
    
    # Calculate new size based on the factor
    new_width = int(width * (1 + padding_factor))
    new_height = int(height * (1 + padding_factor))
    
    # Create new transparent image
    new_img = Image.new("RGBA", (new_width, new_height), (0, 0, 0, 0))
    
    # Paste original in center, with optional horizontal shift
    offset_x = (new_width - width) // 2
    # Add shift (positive = right, negative = left)
    offset_x += int(new_width * shift_x_factor)
    
    offset_y = (new_height - height) // 2
    
    new_img.paste(img, (offset_x, offset_y), img)
    
    new_img.save(output_path)
    print(f"Saved padded image to {output_path} (padding: {padding_factor}, shift_x: {shift_x_factor})")

if __name__ == "__main__":
    base_dir = r"d:\final_year\Cyber_Owl_Mobile_App\CyberOwl_android\assets\logo"
    input_file = os.path.join(base_dir, "app_icon_v2.png")
    output_file = os.path.join(base_dir, "app_icon_v2_padded.png")
    
    try:
        # Increase padding to 0.7 (smaller logo)
        # Shift 6% to the right (Visual Center)
        pad_image(input_file, output_file, padding_factor=0.7, shift_x_factor=0.06)
    except Exception as e:
        print(f"Error: {e}")
