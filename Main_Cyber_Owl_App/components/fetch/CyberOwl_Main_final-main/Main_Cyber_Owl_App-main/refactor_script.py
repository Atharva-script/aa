import re

def main():
    path = r'd:\final_year\Main_Cyber_Owl_App\api_server_updated.py'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Replace remaining basic `device_state['some_key']` to `get_device_state('default')['some_key']`
    # This acts as a fallback for endpoints that haven't been fully migrated to use device_id payloads yet.
    content = re.sub(r"device_state\['([^']+)'\]", r"get_device_state('default')['\1']", content)
    
    # Optional: Fix handle_stop_monitoring
    patch_stop_old = "if get_device_state('default')['running']:"
    patch_stop_new = """device_id = data.get('target_device_id') or "default"
    state = get_device_state(device_id)
    if state['running']:"""
    content = content.replace(patch_stop_old, patch_stop_new)

    # 2. Fix nudity stop event setting in handle_stop_monitoring
    # "if get_device_state('default').get('nudity_stop_event'):" =>
    # "if state.get('nudity_stop_event'):"
    patch_stop2_old = "if get_device_state('default').get('nudity_stop_event'):\n            get_device_state('default')['nudity_stop_event'].set()"
    patch_stop2_new = "if state.get('nudity_stop_event'):\n            state['nudity_stop_event'].set()"
    content = content.replace(patch_stop2_old, patch_stop2_new)

    # 3. Fix emit in handle_stop_monitoring
    patch_stop3_old = "state['running'] = False\n        if state.get('nudity_stop_event'):"
    patch_stop3_new = "state['running'] = False\n        if state.get('nudity_stop_event'):"
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
