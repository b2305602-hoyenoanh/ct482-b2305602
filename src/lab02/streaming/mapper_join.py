#!/usr/bin/env python3
"""Mapper reduce-side join: products.csv (5 cột) và retail_transactions.csv (10 cột).
Khoá ra = product_id [TAB] tag ; tag "0" = bản ghi sản phẩm, "1" = giao dịch.
Nhờ sắp xếp theo (product_id, tag), reducer luôn thấy bản ghi sản phẩm TRƯỚC các giao dịch."""
import sys

for line in sys.stdin:
    p = line.rstrip("\n").split(",")
    if p[0] in ("product_id", "transaction_id"):
        continue                                   # header của hai tệp
    if len(p) == 5:                                # products.csv
        product_id, name, category, brand = p[0], p[1], p[2], p[3]
        print(f"{product_id}\t0\t{name}|{brand}|{category}")
    elif len(p) == 10:                             # retail_transactions.csv
        try:
            revenue = int(p[4]) * float(p[5]) * (1 - float(p[6]))
        except ValueError:
            continue
        print(f"{p[2]}\t1\t{revenue:.2f}")
