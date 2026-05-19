from PIL import Image, ImageDraw

def fix_logo_flood():
    # 1. Load original high-resolution logo (with white background and original white text)
    img = Image.open("assets/icons/mindpilot_app.png").convert("RGBA")
    width, height = img.size
    
    # 2. Perform a Flood Fill starting from all four corners to make the outer white background transparent.
    # We use a threshold of 30 to clear any slight off-white compression artifacts near the edges.
    for corner in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]:
        # Flood fill target is transparent (0, 0, 0, 0)
        ImageDraw.floodfill(img, corner, (0, 0, 0, 0), thresh=30)
    
    # 3. Get the bounding box of the non-transparent logo content to crop it edge-to-edge
    bbox = img.getbbox()
    if bbox:
        print(f"Detected pristine logo bounding box: {bbox}")
        cropped_img = img.crop(bbox)
        
        # Resize to a clean 512x512 square to maintain high-resolution proportions
        final_size = 512
        resized_img = cropped_img.resize((final_size, final_size), Image.Resampling.LANCZOS)
    else:
        print("No bounding box detected, resizing original.")
        final_size = 512
        resized_img = img.resize((final_size, final_size), Image.Resampling.LANCZOS)
        
    # 4. Apply a gorgeous, smooth rounded corner mask to the high-res cropped logo
    mask = Image.new("L", (final_size, final_size), 0)
    draw = ImageDraw.Draw(mask)
    
    # Draw premium rounded corners (radius of 90px for 512x512 is standard for app icons)
    draw.rounded_rectangle(
        [(0, 0), (final_size, final_size)],
        radius=90,
        fill=255
    )
    
    # Paste resized logo onto transparent canvas with the rounded mask
    finished_logo = Image.new("RGBA", (final_size, final_size), (0, 0, 0, 0))
    finished_logo.paste(resized_img, (0, 0), mask=mask)
    
    # 5. Overwrite the files
    finished_logo.save("web/favicon.png", "PNG")
    
    # Create the optimized 256x256 preview image for chat platforms
    preview = finished_logo.resize((256, 256), Image.Resampling.LANCZOS)
    preview.save("web/preview.png", "PNG")
    
    print("Success! Logo cropped edge-to-edge, internal white text fully preserved, and transparent corners applied.")

if __name__ == "__main__":
    fix_logo_flood()
