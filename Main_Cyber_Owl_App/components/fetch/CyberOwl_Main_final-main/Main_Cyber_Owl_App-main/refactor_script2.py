import re

def main():
    path = r'd:\final_year\Main_Cyber_Owl_App\api_server_updated.py'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Update threaded calls in handle_start_monitoring
    # "threading.Thread(target=monitoring_worker, daemon=True)" =>
    # "threading.Thread(target=monitoring_worker, args=(device_id,), daemon=True)"
    content = content.replace(
        "threading.Thread(target=monitoring_worker, daemon=True)", 
        "threading.Thread(target=monitoring_worker, args=(device_id,), daemon=True)"
    )

    # 2. Update worker signatures
    content = content.replace("def monitoring_worker():", "def monitoring_worker(device_id='default'):")
    content = content.replace("def _run_test_mode():", "def _run_test_mode(device_id='default'):")
    
    # 3. Inside worker bodies: get_device_state('default') -> get_device_state(device_id)
    # Be careful not to replace it outside of these bodies!
    # A safe way is just to replace *all* remaining `get_device_state('default')` 
    # to `get_device_state(device_id)` then we fix the endpoints to extract `device_id` as well.
    # Actually, we already updated endpoints in earlier steps! We just need to replace the remaining.
    content = content.replace("get_device_state('default')", "get_device_state(device_id)")
    
    # 4. Endpoints like /health that don't have device_id locally need attention
    # We will just manually fix /api/health to use "default" or loop through them, 
    # but the API allows fetching multiple. For health, `device_id='default'` is fine for now
    health_old = """@app.route('/api/health', methods=['GET'])
def health_check():
    \"\"\"Health check endpoint\"\"\"
    return jsonify({
        'status': 'healthy',
        'detection_available': DETECTION_AVAILABLE,
        'models_loaded': get_device_state(device_id).get('models_loaded', False),
        'loading_status': get_device_state(device_id).get('loading_status', 'Unknown'),
        'timestamp': datetime.now().isoformat()
    })"""
    
    health_new = """@app.route('/api/health', methods=['GET'])
def health_check():
    \"\"\"Health check endpoint\"\"\"
    device_id = request.args.get('target_device_id', 'default')
    return jsonify({
        'status': 'healthy',
        'detection_available': DETECTION_AVAILABLE,
        'models_loaded': get_device_state(device_id).get('models_loaded', False),
        'loading_status': get_device_state(device_id).get('loading_status', 'Unknown'),
        'timestamp': datetime.now().isoformat()
    })"""
    
    content = content.replace(health_old, health_new)
    
    # Since we globally replaced 'default' with device_id, we need to ensure device_id is defined in `init_detection_models_async`
    init_old = "def init_detection_models_async():"
    init_new = "def init_detection_models_async(device_id='default'):"
    content = content.replace(init_old, init_new)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
