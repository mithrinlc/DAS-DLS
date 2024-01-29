from flask import Flask, request, jsonify
import jwt
import redis
import hashlib
import os
from datetime import datetime, timedelta, timezone
import json
import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2 import OperationalError, pool
from contextlib import contextmanager

app = Flask(__name__)

# Redis setup
redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379')
redis_client = redis.from_url(redis_url)

# PostgreSQL setup with connection pooling for efficiency
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://localhost:5432')
db_pool = psycopg2.pool.SimpleConnectionPool(1, 10, DATABASE_URL)

SECRET_KEY = os.environ.get("SECRET_KEY", "THIS_NEEDS_FINISHED")
JWT_ALGORITHM = "HS256"

@contextmanager
def get_db_connection():
    conn = db_pool.getconn()
    try:
        yield conn
    except OperationalError as e:
        print(f"Error in database operation: {e}")
    finally:
        db_pool.putconn(conn)

def initialize_db():
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS vendor_data (
                vendor_id VARCHAR PRIMARY KEY,
                api_key VARCHAR NOT NULL,
                timestamp TIMESTAMP NOT NULL
            );
        """)
        conn.commit()
        cursor.close()

initialize_db()

def generate_api_key(seed):
    return hashlib.sha256(seed.encode()).hexdigest()
    
def is_timestamp_valid(vendor_id, jwt_timestamp):
    with get_db_connection() as conn:
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute("SELECT timestamp FROM vendor_data WHERE vendor_id = %s", (vendor_id,))
        result = cursor.fetchone()
        if result:
            db_timestamp = result['timestamp'].replace(tzinfo=timezone.utc).isoformat()
            return db_timestamp == jwt_timestamp
        return False

def generate_jwt_token(api_key, vendor_id, device_info, timestamp):
    exp = datetime.now(timezone.utc) + timedelta(days=365)
    payload = {
        'api_key': api_key,
        'exp': exp,
        'vendor_id': vendor_id,
        'device_info': device_info,
        'timestamp': timestamp
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=JWT_ALGORITHM)

def store_vendor_data(vendor_id, api_key, timestamp):
    with get_db_connection() as conn:
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        try:
            cursor.execute("INSERT INTO vendor_data (vendor_id, api_key, timestamp) VALUES (%s, %s, %s) ON CONFLICT (vendor_id) DO UPDATE SET api_key = EXCLUDED.api_key, timestamp = EXCLUDED.timestamp", (vendor_id, api_key, timestamp))
            conn.commit()
        except psycopg2.Error as e:
            print(f"Database error: {e}")
            conn.rollback()
        finally:
            cursor.close()

def decrypt_seed(encrypted_seed):
    return encrypted_seed.replace("Encrypted(", "").replace(")", "")

def load_default_config():
    try:
        with open('default_config.json', 'r') as file:
            return json.load(file)
    except FileNotFoundError:
        print("Default configuration file not found.")
        return None

@app.route('/register', methods=['POST'])
def register_device():
    try:
        device_info = request.json.get('deviceInfo')
        model_identifier = device_info.get('modelIdentifier')
        ios_version = device_info.get('iOSVersion')

        if not all([model_identifier, ios_version]):
            return jsonify({'error': 'Missing required device information'}), 400

        encrypted_seed = request.json.get('encryptedSeed')
        if not encrypted_seed:
            return jsonify({'error': 'Missing encrypted seed'}), 400

        vendor_id = decrypt_seed(encrypted_seed)
        api_key = generate_api_key(encrypted_seed)
        current_timestamp = datetime.now(timezone.utc).isoformat()
        jwt_token = generate_jwt_token(api_key, vendor_id, device_info, current_timestamp)
        store_vendor_data(vendor_id, api_key, current_timestamp)

        config_key = f"{model_identifier}_{ios_version}"
        config = redis_client.get(config_key)

        response_data = {'jwt': jwt_token}
        if config:
            response_data['config'] = json.loads(config.decode())
        else:
            default_config = redis_client.get("default_config")
            if default_config:
                response_data['config'] = json.loads(default_config.decode())
            else:
                local_config = load_default_config()
                if local_config:
                    response_data['config'] = local_config
                else:
                    return jsonify({'error': 'Configuration not found'}), 404

        return jsonify(response_data)
    except Exception as e:
        print(f"An error occurred: {e}")
        return jsonify({'error': 'An internal error occurred'}), 500

@app.route('/requestConfig', methods=['POST'])
def request_config():
    try:
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return jsonify({'error': 'Authorization header is missing'}), 401

        token = auth_header.split(" ")[1]
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=[JWT_ALGORITHM])
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'JWT has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid JWT'}), 401

        vendor_id = payload['vendor_id']
        jwt_timestamp = payload['timestamp']

        if not is_timestamp_valid(vendor_id, jwt_timestamp):
            return jsonify({'error': 'Invalid or expired JWT'}), 401

        device_info = payload['device_info']
        config_key = f"{device_info['modelIdentifier']}_{device_info['iOSVersion']}"
        config = redis_client.get(config_key)

        if config:
            return jsonify({'config': json.loads(config.decode())})
        else:
            # Fallback to default config
            default_config = load_default_config()
            if default_config:
                return jsonify({'config': default_config})
            return jsonify({'error': 'Configuration not found'}), 404
    except Exception as e:
        print(f"An error occurred: {e}")
        return jsonify({'error': 'An internal error occurred'}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
