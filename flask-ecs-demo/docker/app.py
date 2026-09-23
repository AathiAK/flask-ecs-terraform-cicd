from flask import Flask, jsonify
import os
import socket
from datetime import datetime

app = Flask(__name__)

# Get container info
CONTAINER_ID = socket.gethostname()

@app.route('/')
def home():
    """Home endpoint"""
    return jsonify({
        'message': 'Hello from ECS EC2!',
        'container_id': CONTAINER_ID,
        'timestamp': datetime.utcnow().isoformat(),
        'deployment': 'ECS EC2 Demo'
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'container_id': CONTAINER_ID,
        'timestamp': datetime.utcnow().isoformat()
    }), 200

@app.route('/info')
def info():
    """Info endpoint"""
    return jsonify({
        'application': 'Flask ECS EC2 Demo',
        'container_id': CONTAINER_ID,
        'environment': os.environ.get('ENVIRONMENT', 'demo'),
        'timestamp': datetime.utcnow().isoformat()
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
