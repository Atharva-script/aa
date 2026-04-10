from PIL import Image
import os

input_path = r'android/nl.png'
output_path = r'android/logo_final_transparent.png'

img = Image.open(input_path).convert('RGBA')
canvas_size = 512
target_size = int(canvas_size * 0.7)

w, h = img.size
scale = target_size / max(w, h)
new_w, new_h = int(w * scale), int(h * scale)

img = img.resize((new_w, new_h), Image.LANCZOS)
new_img = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
offset = ((canvas_size - new_w) // 2, (canvas_size - new_h) // 2)
new_img.paste(img, offset)
new_img.save(output_path)
print(f"Successfully saved scaled icon to {output_path}")
