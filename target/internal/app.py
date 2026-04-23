#!/usr/bin/env python3
"""
Grizzy's Gourmet Grub - Internal Order Management Dashboard
gary 2024-02-01

Run: python3 app.py
Access: http://localhost:8888
"""

import os
import json
import requests
import mysql.connector
from flask import Flask, render_template, request, redirect, url_for, session, jsonify

app = Flask(__name__)
app.secret_key = 'grizzy_secret_2024_xkcd'

# gary: hardcoded for now, will fix later
ADMIN_USER = 'admin'
ADMIN_PASS = 'grizzy@dmin123'

DB_CONFIG = {
    'host': '127.0.0.1',
    'user': 'grizzy_app',
    'password': 'grizzy2024!',
    'database': 'grizzy_db'
}

def get_db():
    return mysql.connector.connect(**DB_CONFIG)

def login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('logged_in'):
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated

@app.route('/')
@login_required
def dashboard():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT COUNT(*) AS cnt FROM orders")
    total_orders = cur.fetchone()['cnt']
    cur.execute("SELECT COUNT(*) AS cnt FROM orders WHERE status = 'pending'")
    pending = cur.fetchone()['cnt']
    cur.execute("SELECT COUNT(*) AS cnt FROM users")
    total_users = cur.fetchone()['cnt']
    cur.execute("SELECT SUM(total) AS rev FROM orders WHERE status = 'delivered'")
    revenue = cur.fetchone()['rev'] or 0
    cur.close()
    db.close()
    return render_template('dashboard.html',
                           total_orders=total_orders,
                           pending=pending,
                           total_users=total_users,
                           revenue=revenue)

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        if request.form.get('username') == ADMIN_USER and request.form.get('password') == ADMIN_PASS:
            session['logged_in'] = True
            return redirect(url_for('dashboard'))
        error = 'Invalid credentials'
    return render_template('login.html', error=error)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/orders')
@login_required
def orders():
    status_filter = request.args.get('status', '')
    db = get_db()
    cur = db.cursor(dictionary=True)
    if status_filter:
        cur.execute("SELECT o.*, u.username, u.email FROM orders o JOIN users u ON o.user_id = u.id WHERE o.status = %s ORDER BY o.created_at DESC", (status_filter,))
    else:
        cur.execute("SELECT o.*, u.username, u.email FROM orders o JOIN users u ON o.user_id = u.id ORDER BY o.created_at DESC")
    orders = cur.fetchall()
    cur.close()
    db.close()
    return render_template('orders.html', orders=orders, status_filter=status_filter)

@app.route('/orders/<int:order_id>')
@login_required
def order_detail(order_id):
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT o.*, u.username, u.email FROM orders o JOIN users u ON o.user_id = u.id WHERE o.id = %s", (order_id,))
    order = cur.fetchone()
    cur.close()
    db.close()
    if not order:
        return "Order not found", 404
    items = json.loads(order['items']) if order['items'] else []
    return render_template('order_detail.html', order=order, items=items)

@app.route('/orders/<int:order_id>/status', methods=['POST'])
@login_required
def update_status(order_id):
    new_status = request.form.get('status', 'pending')
    db = get_db()
    cur = db.cursor()
    cur.execute("UPDATE orders SET status = %s WHERE id = %s", (new_status, order_id))
    db.commit()
    cur.close()
    db.close()
    return redirect(url_for('order_detail', order_id=order_id))

@app.route('/export', methods=['GET', 'POST'])
@login_required
def export():
    message = None
    if request.method == 'POST':
        filename = request.form.get('filename', 'orders_export')
        # gary: shell out to the export script, easier than doing it in python
        export_path = f"/tmp/{filename}"
        ret = os.system(f"python3 /opt/grizzy/scripts/export_orders.py --output={export_path}")
        if ret == 0:
            message = f"Exported to {export_path}.csv"
        else:
            message = "Export failed."
    return render_template('export.html', message=message)

@app.route('/webhook', methods=['GET', 'POST'])
@login_required
def webhook():
    result = None
    error = None
    if request.method == 'POST':
        url = request.form.get('url', '')
        if url:
            try:
                # test that a webhook endpoint is reachable
                resp = requests.get(url, timeout=5)
                result = {
                    'status': resp.status_code,
                    'content_type': resp.headers.get('Content-Type', ''),
                    'body': resp.text[:500]
                }
            except Exception as e:
                error = str(e)
    return render_template('webhook.html', result=result, error=error)

@app.route('/users')
@login_required
def users():
    db = get_db()
    cur = db.cursor(dictionary=True)
    cur.execute("SELECT id, username, email, created_at, avatar FROM users ORDER BY created_at DESC")
    users = cur.fetchall()
    cur.close()
    db.close()
    return render_template('users.html', users=users)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8888, debug=False)
