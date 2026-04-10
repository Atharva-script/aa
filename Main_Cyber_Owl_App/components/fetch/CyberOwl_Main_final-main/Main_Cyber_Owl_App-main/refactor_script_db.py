import re

def main():
    path = r'd:\\final_year\\Main_Cyber_Owl_App\\api_server_updated.py'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # We need to add 'device_id': device_id to detection_history inserts
    # It seems 'device_id' isn't always readily available in every worker function scope natively yet.
    # In `monitoring_worker`, we added `device_id='default'`.
    # Let's cleanly inject it into the insert dicts.

    # 1. Update log_notification
    patch1_old = "def log_notification(notif_type, label, message, email, parent_email=None):"
    patch1_new = "def log_notification(notif_type, label, message, email, parent_email=None, device_id='default'):"
    content = content.replace(patch1_old, patch1_new)
    
    # Add device_id to the insert:
    patch2_old = """'type': notif_type, # 'auth', 'rotation', etc.
            'user_email': email,
            'parent_email': parent_email"""
    patch2_new = """'type': notif_type, # 'auth', 'rotation', etc.
            'user_email': email,
            'device_id': device_id,
            'parent_email': parent_email"""
    content = content.replace(patch2_old, patch2_new)

    # 2. Update _run_test_mode insert
    patch3_old = """'type': 'abuse',
                            'user_email': user_email,
                            'parent_email': parent_email"""
    patch3_new = """'type': 'abuse',
                            'user_email': user_email,
                            'device_id': device_id,
                            'parent_email': parent_email"""
    content = content.replace(patch3_old, patch3_new)

    # 3. Update monitoring_worker audio chunk insert
    patch4_old = """'type': 'abuse',
                                'user_email': user_email, # [NEW] Bind to user
                                'parent_email': parent_email # [NEW] Link alert to parent"""
    patch4_new = """'type': 'abuse',
                                'user_email': user_email, # [NEW] Bind to user
                                'device_id': device_id,
                                'parent_email': parent_email # [NEW] Link alert to parent"""
    content = content.replace(patch4_old, patch4_new)

    # 4. Update scan_live_screen nudity insert
    patch5_old = """'type': 'nudity',
                                'user_email': user_email,
                                'parent_email': parent_email"""
    patch5_new = """'type': 'nudity',
                                'user_email': user_email,
                                'device_id': device_id,
                                'parent_email': parent_email"""
    content = content.replace(patch5_old, patch5_new)

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
