import os
import json
import re
import time
import random
import hashlib
import smtplib
import ssl
from email.message import EmailMessage

from PySide6.QtWidgets import QDialog, QVBoxLayout, QLabel, QLineEdit, QPushButton, QHBoxLayout, QMessageBox

USERS_FILE = os.path.join(os.getcwd(), 'users.json')
OTP_TTL = 300  # seconds
DEFAULT_CREDITS = 100


def _load_users():
    try:
        if os.path.exists(USERS_FILE):
            with open(USERS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
    except Exception:
        pass
    return {}


def _save_users(users):
    try:
        with open(USERS_FILE, 'w', encoding='utf-8') as f:
            json.dump(users, f, indent=2)
        return True
    except Exception:
        return False


def _hash_password(pw: str) -> str:
    return hashlib.sha256(pw.encode('utf-8')).hexdigest()


def validate_email(email: str) -> bool:
    pattern = r'^[\w\.-]+@[\w\.-]+\.[A-Za-z]{2,}$'
    return bool(re.match(pattern, email))


def validate_password(pw: str) -> bool:
    # Minimum 8 chars, at least one upper, one lower, one digit
    if len(pw) < 8:
        return False
    if not re.search(r'[A-Z]', pw):
        return False
    if not re.search(r'[a-z]', pw):
        return False
    if not re.search(r'\d', pw):
        return False
    return True


def _generate_otp() -> str:
    return f"{random.randint(0, 999999):06d}"


def _send_email_smtp(to_addr: str, subject: str, body: str) -> bool:
    # Read SMTP config from environment
    server = os.environ.get('AUTH_SMTP_SERVER')
    port = int(os.environ.get('AUTH_SMTP_PORT', '0') or 0)
    username = os.environ.get('AUTH_SMTP_USERNAME')
    password = os.environ.get('AUTH_SMTP_PASSWORD')
    from_addr = os.environ.get('AUTH_FROM_ADDR', username or '')

    if not server or not port:
        # No SMTP configured; as a fallback, print OTP to console
        print(f"[auth] No SMTP configured; email to {to_addr} would be:\nSubject: {subject}\n{body}")
        return True

    try:
        msg = EmailMessage()
        msg['Subject'] = subject
        msg['From'] = from_addr
        msg['To'] = to_addr
        msg.set_content(body)

        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL(server, port, context=ctx, timeout=30) as smtp:
            if username and password:
                smtp.login(username, password)
            smtp.send_message(msg)
        return True
    except Exception as e:
        print(f"[auth] Failed to send email: {e}")
        return False


class AuthManager:
    def __init__(self):
        self.users = _load_users()
        # otp_store: email -> (otp, expires_at)
        self.otp_store = {}

    def create_user(self, email: str, password: str) -> bool:
        key = email.lower()
        if key in self.users:
            return False
        self.users[key] = {
            'email': email,
            'password_hash': _hash_password(password),
            'credits': DEFAULT_CREDITS,
            'created_at': int(time.time())
        }
        _save_users(self.users)
        return True

    def verify_user(self, email: str, password: str) -> bool:
        key = email.lower()
        u = self.users.get(key)
        if not u:
            return False
        return u.get('password_hash') == _hash_password(password)

    def get_credits(self, email: str) -> int:
        u = self.users.get(email.lower())
        if not u:
            return 0
        return int(u.get('credits', 0))

    def add_credits(self, email: str, amount: int) -> bool:
        key = email.lower()
        if key not in self.users:
            return False
        self.users[key]['credits'] = int(self.users[key].get('credits', 0)) + int(amount)
        return _save_users(self.users)

    def deduct_credits(self, email: str, amount: int) -> bool:
        key = email.lower()
        if key not in self.users:
            return False
        cur = int(self.users[key].get('credits', 0))
        if cur < amount:
            return False
        self.users[key]['credits'] = cur - int(amount)
        return _save_users(self.users)

    def send_otp(self, email: str) -> bool:
        otp = _generate_otp()
        expires = int(time.time()) + OTP_TTL
        self.otp_store[email.lower()] = (otp, expires)
        subj = "Your ToxiGuard OTP"
        body = f"Your one-time login code is: {otp}\nIt expires in {OTP_TTL//60} minutes."
        return _send_email_smtp(email, subj, body)

    def verify_otp(self, email: str, otp: str) -> bool:
        rec = self.otp_store.get(email.lower())
        if not rec:
            return False
        expected, expires = rec
        if int(time.time()) > expires:
            del self.otp_store[email.lower()]
            return False
        if expected == otp:
            del self.otp_store[email.lower()]
            return True
        return False


class LoginDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle('Login / Sign Up')
        self.auth = AuthManager()
        self.logged_in_user = None

        layout = QVBoxLayout(self)

        layout.addWidget(QLabel('Email'))
        self.email_input = QLineEdit()
        layout.addWidget(self.email_input)

        layout.addWidget(QLabel('Password'))
        self.pw_input = QLineEdit()
        self.pw_input.setEchoMode(QLineEdit.Password)
        layout.addWidget(self.pw_input)

        btn_layout = QHBoxLayout()
        self.login_btn = QPushButton('Login')
        self.signup_btn = QPushButton('Sign Up')
        self.otp_btn = QPushButton('Send OTP')
        btn_layout.addWidget(self.login_btn)
        btn_layout.addWidget(self.signup_btn)
        btn_layout.addWidget(self.otp_btn)
        layout.addLayout(btn_layout)

        self.login_btn.clicked.connect(self._on_login)
        self.signup_btn.clicked.connect(self._on_signup)
        self.otp_btn.clicked.connect(self._on_send_otp)

    def _on_login(self):
        email = self.email_input.text().strip()
        pw = self.pw_input.text()
        if not validate_email(email):
            QMessageBox.warning(self, 'Invalid', 'Please enter a valid email address.')
            return
        if not pw:
            QMessageBox.warning(self, 'Invalid', 'Please enter your password.')
            return
        ok = self.auth.verify_user(email, pw)
        if ok:
            self.logged_in_user = email.lower()
            QMessageBox.information(self, 'Welcome', 'Login successful')
            self.accept()
        else:
            QMessageBox.warning(self, 'Failed', 'Invalid credentials')

    def _on_signup(self):
        email = self.email_input.text().strip()
        pw = self.pw_input.text()
        if not validate_email(email):
            QMessageBox.warning(self, 'Invalid', 'Please enter a valid email address.')
            return
        if not validate_password(pw):
            QMessageBox.warning(self, 'Weak', 'Password must be at least 8 chars, include upper, lower, and digit.')
            return
        # send OTP to confirm
        if not self.auth.send_otp(email):
            QMessageBox.warning(self, 'Error', 'Failed to send OTP (check SMTP settings). OTP printed to console if not configured).')
        otp, ok = self._prompt_otp()
        if not ok:
            return
        if not self.auth.verify_otp(email, otp):
            QMessageBox.warning(self, 'Failed', 'OTP invalid or expired')
            return
        created = self.auth.create_user(email, pw)
        if created:
            QMessageBox.information(self, 'Created', f'Account created. {DEFAULT_CREDITS} free credits granted.')
            self.logged_in_user = email.lower()
            self.accept()
        else:
            QMessageBox.warning(self, 'Exists', 'Account already exists. Please login.')

    def _on_send_otp(self):
        email = self.email_input.text().strip()
        if not validate_email(email):
            QMessageBox.warning(self, 'Invalid', 'Please enter a valid email address.')
            return
        if self.auth.send_otp(email):
            QMessageBox.information(self, 'Sent', 'OTP sent to your email (or printed to console).')
        else:
            QMessageBox.warning(self, 'Error', 'Failed to send OTP')

    def _prompt_otp(self):
        # simple blocking prompt
        dlg = QDialog(self)
        dlg.setWindowTitle('Enter OTP')
        v = QVBoxLayout(dlg)
        v.addWidget(QLabel('Enter the 6-digit code sent to your email'))
        otp_in = QLineEdit()
        v.addWidget(otp_in)
        h = QHBoxLayout()
        ok_btn = QPushButton('OK')
        cancel_btn = QPushButton('Cancel')
        h.addWidget(ok_btn)
        h.addWidget(cancel_btn)
        v.addLayout(h)
        ok_btn.clicked.connect(dlg.accept)
        cancel_btn.clicked.connect(dlg.reject)
        res = dlg.exec()
        return otp_in.text().strip(), res == QDialog.Accepted
