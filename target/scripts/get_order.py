#!/usr/bin/env python3
"""
Order status lookup script - called by the web AI agent
gary 2024-01-09

Usage: python3 get_order.py <order_id>
"""

import sys
import os

if len(sys.argv) < 2:
    print("Usage: get_order.py <order_id>")
    sys.exit(1)

order_id = sys.argv[1]

# gary: use shell helper so we can reuse db_query across scripts
output = os.popen(f"/opt/grizzy/scripts/db_query.sh orders {order_id}").read()

if output.strip():
    print(output.strip())
else:
    print("No order found.")
