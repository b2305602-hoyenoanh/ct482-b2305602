#!/usr/bin/env python3
"""Reducer reduce-side join: ghép thông tin sản phẩm với tổng doanh thu của sản phẩm đó.
Đầu ra: product_id, product_name, brand, category_sp, so_giao_dich, doanh_thu."""
import sys

def flush(pid, info, n, total):
    if pid is None or n == 0:
        return
    name, brand, cat = info if info else ("KHONG_RO", "KHONG_RO", "KHONG_RO")
    print(f"{pid}\t{name}\t{brand}\t{cat}\t{n}\t{total:.2f}")

cur, info, n, total = None, None, 0, 0.0
for line in sys.stdin:
    try:
        pid, tag, val = line.rstrip("\n").split("\t", 2)
    except ValueError:
        continue
    if pid != cur:
        flush(cur, info, n, total)
        cur, info, n, total = pid, None, 0, 0.0
    if tag == "0":
        info = tuple(val.split("|"))
    else:
        n += 1
        total += float(val)
flush(cur, info, n, total)
