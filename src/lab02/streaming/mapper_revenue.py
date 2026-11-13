#!/usr/bin/env python3
"""Mapper: doanh thu = quantity * unit_price * (1 - discount), khoá = category."""
import sys

for line in sys.stdin:
    parts = line.rstrip("\n").split(",")
    if len(parts) != 10 or parts[0] == "transaction_id":
        continue                      # bỏ header và dòng hỏng
    try:
        category = parts[3]
        revenue = int(parts[4]) * float(parts[5]) * (1 - float(parts[6]))
    except ValueError:
        continue
    print(f"{category}\t{revenue:.2f}")
    