#!/usr/bin/env python3
"""Reducer: cộng dồn doanh thu theo khoá. Đầu vào đã được Hadoop sắp xếp theo khoá."""
import sys

current_key, total = None, 0.0
for line in sys.stdin:
    try:
        key, value = line.rstrip("\n").split("\t", 1)
        value = float(value)
    except ValueError:
        continue
    if key != current_key:
        if current_key is not None:
            print(f"{current_key}\t{total:.2f}")
        current_key, total = key, 0.0
    total += value
if current_key is not None:
    print(f"{current_key}\t{total:.2f}")
    