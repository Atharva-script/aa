
import ssl
import socket
import certifi
import sys

HOSTNAME = "cluster0.tyryhk7.mongodb.net" 
SHARD_HOST = "ac-wpv3dx8-shard-00-01.tyryhk7.mongodb.net"
PORT = 27017

def test_ssl_handshake(host, port):
    print(f"\n--- Testing SSL Handshake to {host}:{port} ---")
    
    # Method 1: Default Context
    try:
        print("Method 1: Default SSL Context")
        context = ssl.create_default_context()
        with socket.create_connection((host, port), timeout=5) as sock:
            with context.wrap_socket(sock, server_hostname=host) as ssock:
                print(f"  Version: {ssock.version()}")
                print(f"  Cipher: {ssock.cipher()}")
                print("  Success!")
    except Exception as e:
        print(f"  Failed: {e}")

    # Method 2: No Verify
    try:
        print("\nMethod 2: No Verify (CERT_NONE)")
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        with socket.create_connection((host, port), timeout=5) as sock:
            with context.wrap_socket(sock, server_hostname=host) as ssock:
                print(f"  Version: {ssock.version()}")
                print(f"  Cipher: {ssock.cipher()}")
                print("  Success!")
    except Exception as e:
        print(f"  Failed: {e}")

    # Method 3: Certifi
    try:
        print(f"\nMethod 3: Certifi CA ({certifi.where()})")
        context = ssl.create_default_context(cafile=certifi.where())
        with socket.create_connection((host, port), timeout=5) as sock:
            with context.wrap_socket(sock, server_hostname=host) as ssock:
                print(f"  Version: {ssock.version()}")
                print(f"  Cipher: {ssock.cipher()}")
                print("  Success!")
    except Exception as e:
        print(f"  Failed: {e}")

    # Method 4: Google Test
    try:
        print(f"\nMethod 4: Google Test (google.com:443)")
        context = ssl.create_default_context()
        with socket.create_connection(("google.com", 443), timeout=5) as sock:
            with context.wrap_socket(sock, server_hostname="google.com") as ssock:
                print(f"  Version: {ssock.version()}")
                print(f"  Cipher: {ssock.cipher()}")
                print("  Success!")
    except Exception as e:
        print(f"  Failed: {e}")

if __name__ == "__main__":
    test_ssl_handshake(SHARD_HOST, PORT)
