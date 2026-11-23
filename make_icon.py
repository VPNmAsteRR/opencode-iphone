#!/usr/bin/env python3
"""Рисует иконки приложения: знак-искра на тёмной плитке.

Иконка временная: тот же знак, что и в интерфейсе, без чужих символов.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

BG = (19, 19, 20)
SPARK = [(66, 133, 244), (155, 114, 203), (217, 101, 112)]

# (имя файла, сторона в пикселях)
SIZES = [
    ("icon-20@2x", 40),
    ("icon-20@3x", 60),
    ("icon-29@2x", 58),
    ("icon-29@3x", 87),
    ("icon-40@2x", 80),
    ("icon-40@3x", 120),
    ("icon-60@2x", 120),
    ("icon-60@3x", 180),
    ("icon-76@2x", 152),
    ("icon-83.5@2x", 167),
    ("icon-1024", 1024),
]


def gradient(size: int) -> Image.Image:
    """Диагональный градиент из трёх цветов, в квадрате size x size."""
    img = Image.new("RGB", (size, size), SPARK[0])
    draw = ImageDraw.Draw(img)
    span = size * 2
    stops = [(0.0, SPARK[0]), (0.55, SPARK[1]), (1.0, SPARK[2])]

    for y in range(size):
        for x in range(size):
            t = (x + y) / span
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t0 <= t <= t1:
                    k = (t - t0) / (t1 - t0)
                    draw.point(
                        (x, y),
                        fill=tuple(round(c0[j] + (c1[j] - c0[j]) * k) for j in range(3)),
                    )
                    break
    return img


def spark_mask(size: int) -> Image.Image:
    """Четырёхлучевая звезда с вогнутыми краями, как в OCSparkView."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)

    c = size / 2
    r = size / 2
    pull = size * 0.16

    points = [
        (c, c - r),          # верх
        (c + r, c),          # право
        (c, c + r),          # низ
        (c - r, c),          # лево
    ]
    # Каждая дуга квадратичная: точку тянем к центру, чтобы край был вогнутым.
    path = [
        ("M", points[0]),
        ("Q", (c + pull, c - pull), points[1]),
        ("Q", (c + pull, c + pull), points[2]),
        ("Q", (c - pull, c + pull), points[3]),
        ("Q", (c - pull, c - pull), points[0]),
    ]

    polygon = []
    for item in path:
        if item[0] == "M":
            polygon.append(item[1])
        else:
            control, end = item[1], item[2]
            start = polygon[-1]
            for i in range(1, 25):
                t = i / 24
                u = 1 - t
                polygon.append(
                    (
                        u * u * start[0] + 2 * u * t * control[0] + t * t * end[0],
                        u * u * start[1] + 2 * u * t * control[1] + t * t * end[1],
                    )
                )

    draw.polygon(polygon, fill=255)
    return mask


def make_icon(size: int) -> Image.Image:
    tile = Image.new("RGB", (size, size), BG)
    spark_size = int(size * 0.56)
    spark = gradient(spark_size)
    spark.putalpha(spark_mask(spark_size))
    offset = (size - spark_size) // 2
    tile.paste(spark, (offset, offset), spark)
    return tile


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: make_icon.py <App.app>", file=sys.stderr)
        raise SystemExit(2)

    app = Path(sys.argv[1])
    for name, size in SIZES:
        make_icon(size).save(app / f"{name}.png")
    print("иконок:", len(SIZES))


if __name__ == "__main__":
    main()
