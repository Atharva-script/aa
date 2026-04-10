"""
Email Queue Cleanup Script
Removes corrupted/invalid emails from the queue
"""
import json
import os

QUEUE_FILE = "email_system/email_queue.json"

def clean_email_queue():
    if not os.path.exists(QUEUE_FILE):
        print(f"✓ No queue file found at {QUEUE_FILE}")
        return
    
    try:
        with open(QUEUE_FILE, 'r') as f:
            queue = json.load(f)
        
        original_count = len(queue)
        print(f"Found {original_count} queued emails")
        
        # Filter out invalid emails
        valid_queue = []
        removed_count = 0
        
        for email_data in queue:
            recipient = email_data.get('recipient')
            
            # Validate recipient
            if (not recipient or 
                not str(recipient).strip() or 
                str(recipient).strip().lower() in ['none', 'null', '']):
                print(f"  ✗ Removing invalid email: recipient={recipient!r}")
                removed_count += 1
            else:
                valid_queue.append(email_data)
        
        # Save cleaned queue
        with open(QUEUE_FILE, 'w') as f:
            json.dump(valid_queue, f, indent=2)
        
        print(f"\n✓ Queue cleaned!")
        print(f"  Removed: {removed_count}")
        print(f"  Remaining: {len(valid_queue)}")
        
    except Exception as e:
        print(f"✗ Error cleaning queue: {e}")

if __name__ == "__main__":
    print("=" * 50)
    print("CYBER OWL - Email Queue Cleanup")
    print("=" * 50)
    clean_email_queue()
    print("=" * 50)
