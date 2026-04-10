
import socketio
import time

sio = socketio.Client()

@sio.event
def connect():
    print("I'm connected!")
    sio.emit('join', {'room': 'test_room'})

@sio.event
def message(data):
    print('I received a message!')

@sio.on('status')
def on_status(data):
    print('Status:', data)

@sio.on('new_alert')
def on_alert(data):
    print("ALERT RECEIVED:", data)

def main():
    try:
        sio.connect('http://localhost:5000')
        print("Waiting for alerts...")
        sio.wait()
    except Exception as e:
        print(f"Connection failed: {e}")

if __name__ == '__main__':
    main()
