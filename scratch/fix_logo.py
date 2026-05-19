from PIL import Image, ImageDraw

def fix_logo():
    # 1. Load image and convert to RGBA
    img = Image.open("web/favicon.png").convert("RGBA")
    
    # 2. Convert white background pixels to transparent to detect bounds
    datas = img.getdata()
    newData = []
    for item in datas:
        # Detect white background (R, G, B > 245)
        if item[0] >= 245 and item[1] >= 245 and item[2] >= 245:
            newData.append((255, 255, 255, 0)) # transparent
        else:
            newData.append(item)
    
    temp_img = Image.new("RGBA", img.size)
    temp_img.putdata(newData)
    
    # 3. Get bounding box of actual logo pixels to expand it to fit
    bbox = temp_img.getbbox()
    if bbox:
        print(f"Original bounding box of logo: {bbox}")
        # Crop the logo to fit edge-to-edge (eliminates outer white padding)
        cropped_img = temp_img.crop(bbox)
        
        # Resize to a clean 512x512 square to keep perfect high-res proportions
        final_size = 512
        resized_img = cropped_img.resize((final_size, final_size), Image.Resampling.LANCZOS)
    else:
        print("No bounding box found, using original image.")
        final_size = 512
        resized_img = temp_img.resize((final_size, final_size), Image.Resampling.LANCZOS)

    # 4. Apply a gorgeous rounded rectangle mask to the cropped logo
    mask = Image.new("L", (final_size, final_size), 0)
    draw = ImageDraw.Draw(mask)
    
    # Draw standard app icon rounded corners (radius of 90px for 512x512 is standard)
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
    
    print("Done! Logo expanded edge-to-edge and transparent corners successfully applied.")

if __name__ == "__main__":
    fix_logo()
