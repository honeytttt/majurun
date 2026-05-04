from PIL import Image
import os

def create_app_icon(source_path, output_path):
    try:
        # Open the source image
        img = Image.open(source_path)
        
        # Ensure it is RGB (flattened)
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Resize to 1024x1024 using high-quality lanczos filter
        img = img.resize((1024, 1024), Image.Resampling.LANCZOS)
        
        # Save with 72 DPI
        img.save(output_path, 'PNG', dpi=(72, 72))
        print(f"Successfully created {output_path} at 1024x1024, 72 DPI")
        return True
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    source = "majurun-logo.jpg"
    target = "may1.png"
    create_app_icon(source, target)
