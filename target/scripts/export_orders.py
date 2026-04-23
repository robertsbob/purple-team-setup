#!/usr/bin/env python3
"""
Export orders to CSV
gary 2024-02-15

Usage: python3 export_orders.py --output=/tmp/orders
"""

import sys
import csv
import mysql.connector

output_file = '/tmp/orders'
for arg in sys.argv[1:]:
    if arg.startswith('--output='):
        output_file = arg.split('=', 1)[1]

db = mysql.connector.connect(
    host='127.0.0.1',
    user='grizzy_app',
    password='grizzy2024!',
    database='grizzy_db'
)
cur = db.cursor(dictionary=True)
cur.execute("SELECT o.id, u.username, u.email, o.total, o.status, o.delivery_date, o.address, o.created_at FROM orders o JOIN users u ON o.user_id = u.id ORDER BY o.created_at DESC")
rows = cur.fetchall()
cur.close()
db.close()

with open(output_file + '.csv', 'w', newline='') as f:
    if rows:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

print(f"Exported {len(rows)} orders.")
