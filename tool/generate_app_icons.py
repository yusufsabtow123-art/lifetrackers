"""Generate platform icon files from the approved Life Tracker source mark."""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "life_tracker_icon_source.png"


def square_source() -> Image.Image:
    image = Image.open(SOURCE).convert("RGBA")
    edge = min(image.size)
    left = (image.width - edge) // 2
    top = (image.height - edge) // 2
    return image.crop((left, top, left + edge, top + edge))


def save_png(source: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    source.resize((size, size), Image.Resampling.LANCZOS).save(
        path, "PNG", optimize=True
    )


def main() -> None:
    source = square_source()

    android = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    for relative, size in android.items():
        save_png(source, ROOT / "android/app/src/main/res" / relative, size)

    ios = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    ios_root = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, size in ios.items():
        save_png(source, ios_root / name, size)

    macos_root = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save_png(source, macos_root / f"app_icon_{size}.png", size)

    windows_icon = ROOT / "windows/runner/resources/app_icon.ico"
    windows_icon.parent.mkdir(parents=True, exist_ok=True)
    source.save(
        windows_icon,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


if __name__ == "__main__":
    main()
