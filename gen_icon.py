"""
Generates the Scholaro launcher icon:
- Deep blue rounded square background
- White graduation cap (mortar board) with gold tassel
Outputs: Android mipmap PNGs + Windows app_icon.ico
"""

from PIL import Image, ImageDraw
import os, struct, io

def draw_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # ── Background ──────────────────────────────────────────────────────────────
    r = int(size * 0.22)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r,
                        fill=(21, 101, 192, 255))   # #1565C0

    # ── Graduation cap (mortar board) ───────────────────────────────────────────
    cx   = size // 2
    # Diamond (flat top of cap) – flattened rhombus
    dw   = int(size * 0.60)   # half-width of diamond
    dh   = int(size * 0.26)   # half-height of diamond
    cy_d = int(size * 0.42)   # vertical center of diamond

    diamond = [
        (cx,        cy_d - dh),   # top
        (cx + dw,   cy_d),        # right
        (cx,        cy_d + dh),   # bottom
        (cx - dw,   cy_d),        # left
    ]
    d.polygon(diamond, fill=(255, 255, 255, 255))

    # Dark edge on diamond bottom-left face for depth
    shadow = [
        (cx,        cy_d),
        (cx + dw,   cy_d),
        (cx,        cy_d + dh),
    ]
    d.polygon(shadow, fill=(200, 220, 255, 80))

    # Body (trapezoid below diamond center)
    bw_top = int(size * 0.16)
    bw_bot = int(size * 0.22)
    body_top    = cy_d + dh
    body_bottom = int(size * 0.75)
    body_pts = [
        (cx - bw_top, body_top),
        (cx + bw_top, body_top),
        (cx + bw_bot, body_bottom),
        (cx - bw_bot, body_bottom),
    ]
    d.polygon(body_pts, fill=(255, 255, 255, 255))

    # Bottom cap of body (rounded effect)
    arc_h = int(size * 0.06)
    d.ellipse([cx - bw_bot, body_bottom - arc_h,
               cx + bw_bot, body_bottom + arc_h],
              fill=(255, 255, 255, 255))

    # Button on top of diamond
    btn_r = max(2, int(size * 0.025))
    d.ellipse([cx - btn_r, cy_d - dh - btn_r,
               cx + btn_r, cy_d - dh + btn_r],
              fill=(255, 215, 0, 255))   # gold

    # Tassel (hanging from right corner of diamond)
    tx = cx + dw
    ty = cy_d
    tlen = int(size * 0.22)
    tw   = max(2, size // 55)
    d.line([(tx, ty), (tx, ty + tlen)],
           fill=(255, 215, 0, 255), width=tw)
    ball_r = max(3, size // 38)
    d.ellipse([tx - ball_r, ty + tlen - ball_r,
               tx + ball_r, ty + tlen + ball_r],
              fill=(255, 215, 0, 255))

    return img


# ── Generate Android icons ───────────────────────────────────────────────────
base = r'C:\Users\Cenkay\Desktop\grading_app'

sizes = {
    'mipmap-mdpi':    48,
    'mipmap-hdpi':    72,
    'mipmap-xhdpi':   96,
    'mipmap-xxhdpi':  144,
    'mipmap-xxxhdpi': 192,
}

for folder, px in sizes.items():
    path = os.path.join(base, 'android', 'app', 'src', 'main', 'res', folder, 'ic_launcher.png')
    img = draw_icon(px).convert('RGB')
    img.save(path)
    print(f'  Saved {px}x{px} -> {folder}')

# ── Generate Windows .ico ────────────────────────────────────────────────────
ico_sizes = [256, 128, 64, 48, 32, 16]
ico_images = []
for px in ico_sizes:
    ico_images.append(draw_icon(px).convert('RGBA'))

ico_path = os.path.join(base, 'windows', 'runner', 'resources', 'app_icon.ico')

# Build ICO manually: header + directory + image data
def make_ico(images):
    count = len(images)
    buf = io.BytesIO()

    # ICO header
    buf.write(struct.pack('<HHH', 0, 1, count))

    # Reserve space for directory
    dir_offset = 6 + count * 16
    image_bufs = []
    for img in images:
        b = io.BytesIO()
        img.save(b, format='PNG')
        image_bufs.append(b.getvalue())

    offset = dir_offset
    for i, (img, data) in enumerate(zip(images, image_bufs)):
        w = img.width if img.width < 256 else 0
        h = img.height if img.height < 256 else 0
        buf.write(struct.pack('<BBBBHHII', w, h, 0, 0, 1, 32, len(data), offset))
        offset += len(data)

    for data in image_bufs:
        buf.write(data)

    return buf.getvalue()

with open(ico_path, 'wb') as f:
    f.write(make_ico(ico_images))
print(f'  Saved Windows .ico -> {ico_path}')

print('Done.')
