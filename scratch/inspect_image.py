from PIL import Image

def analyze():
    img = Image.open("web/favicon.png")
    print(f"Size: {img.size}")
    print(f"Mode: {img.mode}")
    
    # Check the corners
    corners = [
        (0, 0),
        (img.width - 1, 0),
        (0, img.height - 1),
        (img.width - 1, img.height - 1),
        (10, 10),
        (img.width - 11, 10)
    ]
    for c in corners:
        pixel = img.getpixel(c)
        print(f"Pixel at {c}: {pixel}")

if __name__ == "__main__":
    analyze()
