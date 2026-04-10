import smtplib
import os
import json
import time
import socket
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.image import MIMEImage
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# GLOBAL EMAIL DISABLE FLAG - Set to True to disable ALL email sending
EMAIL_DISABLED = True

class EmailManager:
    """
    Redesigned Email Manager with robust error handling and queue management.
    Supports Gmail SMTP with app passwords.
    """
    
    # Default Gmail SMTP configuration
    SMTP_SERVER = 'smtp.gmail.com'
    SMTP_PORT = 587
    
    def __init__(self, email_user, email_pass, queue_file='email_queue.json'):
        """
        Initialize Email Manager with credentials.
        
        Args:
            email_user (str): Gmail address (e.g., cyberowl19@gmail.com)
            email_pass (str): Gmail app password (16 characters, no spaces)
        """
        self.email_user = email_user
        self.email_pass = email_pass.replace(" ", "")  # Remove any spaces
        self.base_dir = os.path.dirname(__file__)
        self.template_dir = os.path.join(self.base_dir, 'templates')
        self.queue_file = os.path.join(self.base_dir, queue_file)
        
        # Validate credentials
        if not self.email_user or not self.email_pass:
            logger.warning("Email credentials not provided. Email functionality will be limited.")
        
        self._load_queue_count()
        logger.info(f"Email Manager initialized with user: {self.email_user}")

    def _load_queue_count(self):
        """Load and display queue count on initialization."""
        if os.path.exists(self.queue_file):
            try:
                with open(self.queue_file, 'r') as f:
                    queue = json.load(f)
                    count = len(queue)
                    if count > 0:
                        logger.info(f"Email queue loaded: {count} pending emails")
                    else:
                        logger.info("Email queue is empty")
            except Exception as e:
                logger.error(f"Failed to load email queue: {e}")
        else:
            logger.info("No pending emails in queue")

    def _check_internet(self):
        """Check if there is an active internet connection."""
        try:
            socket.create_connection(("8.8.8.8", 53), timeout=3)
            return True
        except OSError:
            logger.warning("No internet connection detected")
            return False

    def _save_to_queue(self, email_data):
        """Save a failed email to the JSON queue file."""
        try:
            queue = []
            if os.path.exists(self.queue_file):
                with open(self.queue_file, 'r') as f:
                    content = f.read()
                    if content:
                        queue = json.loads(content)
            
            email_data['queued_at'] = datetime.now().isoformat()
            queue.append(email_data)
            
            with open(self.queue_file, 'w') as f:
                json.dump(queue, f, indent=2)
            
            logger.info(f"Email queued: {email_data.get('recipient', 'Unknown')}")
        except Exception as e:
            logger.error(f"Failed to save email to queue: {e}")

    def _remove_from_queue(self, email_data):
        """Remove a sent email from the queue."""
        try:
            if not os.path.exists(self.queue_file):
                return
            
            with open(self.queue_file, 'r') as f:
                queue = json.load(f)
            
            # Remove the email (compare by recipient and subject)
            queue = [e for e in queue if not (
                e.get('recipient') == email_data.get('recipient') and
                e.get('subject') == email_data.get('subject')
            )]
            
            with open(self.queue_file, 'w') as f:
                json.dump(queue, f, indent=2)
            
            logger.info(f"Email removed from queue: {email_data.get('recipient', 'Unknown')}")
        except Exception as e:
            logger.error(f"Failed to remove email from queue: {e}")

    def _send_email_smtp(self, recipient, subject, html_body, images=None):
        """
        Internal method to send email via SMTP.
        
        Args:
            recipient (str): Recipient email address
            subject (str): Email subject
            html_body (str): HTML content of the email
            images (list): Optional list of image paths to attach
            
        Returns:
            bool: True if sent successfully, False otherwise
        """
        # Check global disable flag
        if EMAIL_DISABLED:
            logger.info(f"Email sending disabled - skipping email to {recipient}")
            return True  # Return True to prevent retry/queue
        
        try:
            # Create message
            msg = MIMEMultipart('related')
            msg['From'] = self.email_user
            msg['To'] = recipient
            msg['Subject'] = subject
            
            # Attach HTML body
            msg.attach(MIMEText(html_body, 'html'))
            
            # Attach images if provided
            if images:
                for image_path, image_cid in images:
                    # Try absolute path first, then relative to assets
                    full_img_path = image_path if os.path.isabs(image_path) else os.path.join(self.template_dir, 'assets', image_path)
                    
                    if os.path.exists(full_img_path):
                        try:
                            with open(full_img_path, 'rb') as f:
                                img_data = f.read()
                                image = MIMEImage(img_data)
                                if image_cid and 'attachment' not in image_cid:
                                    image.add_header('Content-ID', f'<{image_cid}>')
                                    image.add_header('Content-Disposition', 'inline', filename=os.path.basename(image_path))
                                else:
                                    # Treat as regular attachment if CID is None or has 'attachment' keyword
                                    image.add_header('Content-Disposition', 'attachment', filename=os.path.basename(image_path))
                                msg.attach(image)
                        except Exception as img_err:
                            logger.error(f"Failed to attach image {image_path}: {img_err}")
                    else:
                        logger.warning(f"Image not found at path: {full_img_path}")
            
            # Send via SMTP
            logger.info(f"Connecting to {self.SMTP_SERVER}:{self.SMTP_PORT}...")
            server = smtplib.SMTP(self.SMTP_SERVER, self.SMTP_PORT, timeout=30)
            server.starttls()
            
            logger.info(f"Logging in as {self.email_user}...")
            server.login(self.email_user, self.email_pass)
            
            logger.info(f"Sending email to {recipient}...")
            server.send_message(msg)
            server.quit()
            
            logger.info(f"✅ Email sent successfully to {recipient}")
            return True

        except smtplib.SMTPAuthenticationError as e:
            logger.error(f"❌ SMTP Authentication failed: {e}")
            logger.error("Please check your Gmail app password is correct")
            return False
        except smtplib.SMTPException as e:
            logger.error(f"❌ SMTP error: {e}")
            return False
        except Exception as e:
            logger.error(f"❌ Failed to send email: {e}")
            return False

    def send_email(self, recipient, template_name, context, images=None):
        """
        Send an email using a template.
        
        Args:
            recipient (str): Recipient email address
            template_name (str): Name of the HTML template file (without .html)
            context (dict): Variables to replace in the template
            images (list): Optional list of (image_path, cid) tuples
            
        Returns:
            bool: True if sent successfully
        """
        # Check global disable flag
        if EMAIL_DISABLED:
            logger.info(f"Email sending disabled - skipping email to {recipient}")
            return True  # Return True to prevent retry/queue
        
        try:
            # Validate recipient FIRST (prevent queuing invalid emails)
            if not recipient or not str(recipient).strip() or str(recipient).strip().lower() == 'none':
                logger.error(f"Invalid recipient: {recipient!r} - Email not sent or queued")
                return False
            
            # Check credentials
            if not self.email_user or not self.email_pass:
                logger.error("Email credentials not configured")
                return False
            
            # Check internet connection
            if not self._check_internet():
                logger.warning("No internet connection. Queuing email.")
                self._save_to_queue({
                    'recipient': recipient,
                    'template_name': template_name,
                    'context': context,
                    'images': images,
                    'subject': context.get('subject', 'Notification')
                })
                return False

            
            # Load template
            template_path = os.path.join(self.template_dir, f'{template_name}.html')
            if not os.path.exists(template_path):
                logger.error(f"Template not found: {template_path}")
                return False
            
            with open(template_path, 'r', encoding='utf-8') as f:
                html_body = f.read()
            
            # Replace context variables
            for key, value in context.items():
                html_body = html_body.replace(f'{{{{{key}}}}}', str(value))
            
            subject = context.get('subject', 'Notification')
            
            # Send email
            success = self._send_email_smtp(recipient, subject, html_body, images)
            
            if success:
                # Remove from queue if it was queued
                self._remove_from_queue({
                    'recipient': recipient,
                    'subject': subject
                })
            else:
                # Queue for retry
                self._save_to_queue({
                    'recipient': recipient,
                    'template_name': template_name,
                    'context': context,
                    'images': images,
                    'subject': subject
                })
            
            return success
            
        except Exception as e:
            logger.error(f"Error in send_email: {e}")
            return False

    def retry_queued_emails(self):
        """Attempt to send all queued emails."""
        if not os.path.exists(self.queue_file):
            logger.info("No queued emails to retry")
            return
        
        try:
            with open(self.queue_file, 'r') as f:
                queue = json.load(f)
            
            if not queue:
                logger.info("Email queue is empty")
                return
            
            logger.info(f"Retrying {len(queue)} queued emails...")
            
            for email_data in queue[:]:  # Copy to avoid modification during iteration
                success = self.send_email(
                    email_data['recipient'],
                    email_data['template_name'],
                    email_data['context'],
                    email_data.get('images')
                )
                
                if success:
                    logger.info(f"Successfully sent queued email to {email_data['recipient']}")
                else:
                    logger.warning(f"Failed to send queued email to {email_data['recipient']}")
                
                time.sleep(1)  # Rate limiting
            
        except Exception as e:
            logger.error(f"Error retrying queued emails: {e}")

    def get_queue_count(self):
        """Get the number of emails in the queue."""
        if not os.path.exists(self.queue_file):
            return 0
        
        try:
            with open(self.queue_file, 'r') as f:
                queue = json.load(f)
                return len(queue)
        except:
            return 0
