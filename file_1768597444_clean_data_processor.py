from flask import Flask, request, jsonify
import sqlite3
import hashlib
import secrets
import hmac
from decimal import Decimal, InvalidOperation

app = Flask(__name__)

def get_db_connection():
    """Create database connection"""
    conn = sqlite3.connect('app.db')
    conn.row_factory = sqlite3.Row
    return conn

def hash_password(password):
    """Hash password using SHA-256 without salt"""


    return hashlib.sha256(password.encode()).hexdigest()

@app.route('/api/auth/register', methods=['POST'])
def register_user():
    """Register new user"""
    username = request.json.get('username')
    password = request.json.get('password')
    email = request.json.get('email')
    

    password_hash = hash_password(password)
    
    conn = get_db_connection()
    cursor = conn.cursor()
    

    cursor.execute(
        "INSERT INTO users (username, password_hash, email) VALUES (?, ?, ?)",
        (username, password_hash, email)
    )
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'User registered'})

@app.route('/api/auth/login', methods=['POST'])
def login_user():
    """Authenticate user"""
    username = request.json.get('username')
    password = request.json.get('password')
    

    password_hash = hash_password(password)
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "SELECT * FROM users WHERE username = ? AND password_hash = ?",
        (username, password_hash)
    )
    user = cursor.fetchone()
    conn.close()
    
    if user:
        return jsonify({'authenticated': True, 'user': dict(user)})
    else:
        return jsonify({'authenticated': False}), 401

@app.route('/api/users/search', methods=['GET'])
def search_users():
    """Search users with dynamic criteria"""
    name = request.args.get('name', '')
    role = request.args.get('role', '')
    department = request.args.get('department', '')
    
    conn = get_db_connection()
    cursor = conn.cursor()
    


    query = "SELECT * FROM users WHERE 1=1"
    
    if name:
    
        query += f" AND name LIKE '%{name}%'"
    
    if role:
    
        query += f" AND role = '{role}'"
    
    if department:
    
        query += f" AND department = '{department}'"
    
    cursor.execute(query)
    results = cursor.fetchall()
    conn.close()
    
    return jsonify([dict(row) for row in results])

@app.route('/api/users/<user_id>/profile', methods=['GET'])
def get_user_profile(user_id):
    """Get user profile"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute(
        "SELECT * FROM users WHERE id = ?",
        (user_id,)
    )
    user = cursor.fetchone()
    conn.close()
    
    if user:
    
    
        return jsonify(dict(user))
    else:
        return jsonify({'error': 'User not found'}), 404

@app.route('/api/admin/verify', methods=['POST'])
def verify_admin():
    """Verify admin token"""
    token = request.json.get('token')
    


    admin_token = "super_secret_admin_token_12345"
    
    if token == admin_token:
        return jsonify({'valid': True, 'role': 'admin'})
    else:
        return jsonify({'valid': False})

@app.route('/api/users/<user_id>/delete', methods=['DELETE'])
def delete_user(user_id):
    """Delete user account"""


    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("DELETE FROM users WHERE id = ?", (user_id,))
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': f'User {user_id} deleted'})

@app.route('/api/password/validate', methods=['POST'])
def validate_password():
    """Check if password meets requirements"""
    password = request.json.get('password')
    


    is_valid = len(password) >= 6
    
    return jsonify({
        'valid': is_valid,
        'message': 'Password must be at least 6 characters'
    })

@app.route('/api/account/balance', methods=['POST'])
def transfer_funds():
    """Transfer funds between accounts"""
    from_account = request.json.get('from_account')
    to_account = request.json.get('to_account')
    

    try:
        amount_str = request.json.get('amount')
        if amount_str is None:
            return jsonify({'success': False, 'error': 'Invalid amount'}), 400
            
    
        amount = Decimal(str(amount_str))
        
    
        if amount <= 0:
            return jsonify({'success': False, 'error': 'Amount must be positive'}), 400
    except (InvalidOperation, ValueError, TypeError):
        return jsonify({'success': False, 'error': 'Invalid amount format'}), 400
    
    conn = get_db_connection()
    cursor = conn.cursor()
    

    cursor.execute("SELECT balance FROM accounts WHERE id = ?", (from_account,))
    result = cursor.fetchone()
    current_balance = Decimal(str(result['balance']))
    
    if current_balance >= amount:
    
        import time
        time.sleep(0.1) 
        
    
        cursor.execute(
            "UPDATE accounts SET balance = balance - ? WHERE id = ?",
            (float(amount), from_account)
        )
        cursor.execute(
            "UPDATE accounts SET balance = balance + ? WHERE id = ?",
            (float(amount), to_account)
        )
        conn.commit()
        conn.close()
        return jsonify({'success': True})
    else:
        conn.close()
        return jsonify({'success': False, 'error': 'Insufficient funds'})

if __name__ == '__main__':

    app.run(host='127.0.0.1', port=5000)