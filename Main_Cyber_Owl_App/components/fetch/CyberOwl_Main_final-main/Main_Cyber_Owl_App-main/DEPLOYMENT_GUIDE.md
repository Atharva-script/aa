# Cyber Owl Backend - Deployment Guide

## Table of Contents
1. [System Requirements](#system-requirements)
2. [MongoDB Setup](#mongodb-setup)
3. [Backend Installation](#backend-installation)
4. [Configuration](#configuration)
5. [Running as a Service](#running-as-a-service)
6. [Production Deployment](#production-deployment)
7. [Troubleshooting](#troubleshooting)

---

## System Requirements

### Minimum Requirements
- **OS**: Windows 10+, Ubuntu 20.04+, or macOS 11+
- **Python**: 3.8 or higher
- **RAM**: 8GB (16GB recommended for AI models)
- **Storage**: 5GB free space
- **Internet**: Required for MongoDB Atlas and email alerts

### Recommended for Production
- **CPU**: 4+ cores
- **RAM**: 16GB+
- **SSD**: For faster model loading
- **Network**: Stable connection with low latency

---

## MongoDB Setup

### Option 1: MongoDB Atlas (Recommended for Production)

1. **Create Account**
   - Go to [MongoDB Atlas](https://cloud.mongodb.com)
   - Sign up for a free account

2. **Create Cluster**
   - Click "Build a Database"
   - Select "Shared" (Free tier) or "Dedicated" (Production)
   - Choose your cloud provider and region (closest to your users)
   - Click "Create Cluster"

3. **Configure Database Access**
   - Go to "Database Access" in left sidebar
   - Click "Add New Database User"
   - Create username and password (save these!)
   - Set privileges to "Read and write to any database"

4. **Configure Network Access**
   - Go to "Network Access" in left sidebar
   - Click "Add IP Address"
   - For testing: Click "Allow Access from Anywhere" (0.0.0.0/0)
   - For production: Add your server's specific IP address

5. **Get Connection String**
   - Go to "Database" in left sidebar
   - Click "Connect" on your cluster
   - Choose "Connect your application"
   - Copy the connection string
   - Replace `<password>` with your database user password
   - Add database name: `mongodb+srv://username:password@cluster.mongodb.net/cyberowl?retryWrites=true&w=majority`

### Option 2: Local MongoDB (Development Only)

1. **Install MongoDB**
   - **Windows**: Download from [MongoDB Download Center](https://www.mongodb.com/try/download/community)
   - **Ubuntu**: 
     ```bash
     sudo apt-get install mongodb
     sudo systemctl start mongodb
     ```
   - **macOS**: 
     ```bash
     brew install mongodb-community
     brew services start mongodb-community
     ```

2. **Connection String**
   ```
   MONGO_URI=mongodb://localhost:27017/cyberowl
   ```

---

## Backend Installation

### 1. Clone/Extract Project

```bash
cd /path/to/installation
# Extract your Cyber Owl package here
```

### 2. Create Virtual Environment (Recommended)

**Windows:**
```powershell
python -m venv venv
.\venv\Scripts\activate
```

**Linux/Mac:**
```bash
python3 -m venv venv
source venv/bin/activate
```

### 3. Install Dependencies

```bash
cd Main_Cyber_Owl_App/main_login_system
pip install -r requirements.txt
```

**Note**: This may take 10-20 minutes due to large ML models (PyTorch, Transformers)

### 4. Download NLTK Data

```bash
python -c "import nltk; nltk.download('punkt'); nltk.download('stopwords')"
```

---

## Configuration

### 1. Create Environment File

```bash
cd Main_Cyber_Owl_App
cp .env.template .env
```

### 2. Edit Configuration

Open `.env` in a text editor and configure:

#### Email Configuration (Required)

```bash
# Your Gmail account for sending alerts
MAIL_USERNAME=your-email@gmail.com

# Gmail App Password (NOT your regular password!)
# Get from: https://myaccount.google.com/apppasswords
MAIL_PASSWORD=your-16-char-app-password

# Parent's email to receive alerts
ALERT_EMAIL_TO=parent@example.com
```

#### Database Configuration (Required)

```bash
# Use your MongoDB Atlas connection string
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/cyberowl?retryWrites=true&w=majority
```

#### Server Configuration (Optional)

```bash
# Listen on all interfaces (required for remote access)
SERVER_HOST=0.0.0.0

# Port number
SERVER_PORT=5000

# Generate a secure secret key
SECRET_KEY=$(python -c "import secrets; print(secrets.token_hex(32))")
```

### 3. Test Configuration

```bash
cd Main_Cyber_Owl_App
python db_test.py  # Test MongoDB connection
python email_test.py  # Test email sending
```

---

## Running as a Service

### Windows Service (Using NSSM)

1. **Download NSSM**
   - Download from [nssm.cc](https://nssm.cc/download)
   - Extract to `C:\nssm`

2. **Create Service**
   ```powershell
   cd C:\nssm\win64
   .\nssm.exe install CyberOwlBackend "C:\path\to\venv\Scripts\python.exe" "C:\path\to\Main_Cyber_Owl_App\api_server_updated.py"
   .\nssm.exe set CyberOwlBackend AppDirectory "C:\path\to\Main_Cyber_Owl_App"
   .\nssm.exe set CyberOwlBackend DisplayName "Cyber Owl Backend Server"
   .\nssm.exe set CyberOwlBackend Description "Cyber Owl Parental Control Backend"
   .\nssm.exe set CyberOwlBackend Start SERVICE_AUTO_START
   ```

3. **Start Service**
   ```powershell
   .\nssm.exe start CyberOwlBackend
   ```

4. **Check Status**
   ```powershell
   .\nssm.exe status CyberOwlBackend
   ```

### Linux Service (Using systemd)

1. **Create Service File**
   ```bash
   sudo nano /etc/systemd/system/cyberowl.service
   ```

2. **Add Configuration**
   ```ini
   [Unit]
   Description=Cyber Owl Backend Server
   After=network.target

   [Service]
   Type=simple
   User=your-username
   WorkingDirectory=/path/to/Main_Cyber_Owl_App
   Environment="PATH=/path/to/venv/bin"
   ExecStart=/path/to/venv/bin/python api_server_updated.py
   Restart=always
   RestartSec=10

   [Install]
   WantedBy=multi-user.target
   ```

3. **Enable and Start**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable cyberowl
   sudo systemctl start cyberowl
   sudo systemctl status cyberowl
   ```

---

## Production Deployment

### Using Nginx Reverse Proxy (Recommended)

1. **Install Nginx**
   ```bash
   # Ubuntu
   sudo apt-get install nginx

   # Windows: Download from nginx.org
   ```

2. **Configure Nginx**
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;

       location / {
           proxy_pass http://127.0.0.1:5000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

3. **Enable SSL with Let's Encrypt**
   ```bash
   sudo apt-get install certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```

### Cloud Deployment Options

#### AWS EC2
1. Launch Ubuntu instance (t3.medium or larger)
2. Configure security groups (ports 80, 443, 5000)
3. Follow Linux installation steps above
4. Use Elastic IP for static address

#### Google Cloud Platform
1. Create Compute Engine instance
2. Configure firewall rules
3. Follow Linux installation steps
4. Use static external IP

#### DigitalOcean
1. Create Droplet (Ubuntu, 4GB+ RAM)
2. Follow Linux installation steps
3. Configure firewall
4. Use floating IP

---

## Troubleshooting

### Common Issues

#### 1. MongoDB Connection Failed

**Error**: `ServerSelectionTimeoutError`

**Solutions**:
- Verify MongoDB Atlas IP whitelist includes your server IP
- Check connection string format
- Ensure database user credentials are correct
- Test with: `python db_test.py`

#### 2. Email Not Sending

**Error**: `SMTPAuthenticationError`

**Solutions**:
- Verify you're using Gmail App Password, not regular password
- Enable 2FA on Gmail account
- Check for spaces in password (remove them)
- Test with: `python email_test.py`

#### 3. Port Already in Use

**Error**: `Address already in use`

**Solutions**:
```bash
# Windows
netstat -ano | findstr :5000
taskkill /PID <process_id> /F

# Linux
sudo lsof -i :5000
sudo kill -9 <process_id>
```

#### 4. Models Not Loading

**Error**: `Failed to load model`

**Solutions**:
- Ensure sufficient RAM (8GB minimum)
- Check internet connection for first-time download
- Verify disk space (models are ~2GB)
- Try: `pip install --upgrade transformers torch`

#### 5. Permission Denied

**Error**: `PermissionError`

**Solutions**:
```bash
# Linux
sudo chown -R $USER:$USER /path/to/Main_Cyber_Owl_App
chmod +x api_server_updated.py

# Windows: Run as Administrator
```

### Logs and Debugging

**View Logs**:
```bash
# Check rotation log
tail -f Main_Cyber_Owl_App/rotation.log

# Check screen monitor log
tail -f Main_Cyber_Owl_App/screen_monitor.log

# Service logs (Linux)
sudo journalctl -u cyberowl -f
```

**Enable Debug Mode** (Development only):
```bash
# In .env
DEBUG_MODE=True
LOG_LEVEL=DEBUG
```

### Performance Optimization

1. **Increase Worker Threads**
   - Edit `api_server_updated.py`
   - Adjust ThreadPoolExecutor size

2. **Database Indexing**
   - Indexes are created automatically
   - Monitor with MongoDB Atlas performance tab

3. **Memory Management**
   - Close unused detection modules
   - Adjust model batch sizes

### Getting Help

- **Email**: support@cyberowl.com
- **GitHub Issues**: [Your Repository URL]
- **Documentation**: Check README.md files

---

## Security Checklist

Before going live:

- [ ] Changed default SECRET_KEY
- [ ] Using strong MongoDB password
- [ ] Enabled SSL/HTTPS
- [ ] Restricted MongoDB network access
- [ ] Using Gmail App Password (not regular password)
- [ ] Disabled DEBUG_MODE
- [ ] Set up firewall rules
- [ ] Regular backups configured
- [ ] Monitoring/alerting set up

---

## Next Steps

1. Install and configure PC Application
2. Install and configure Mobile Application
3. Test end-to-end system
4. Monitor logs for first 24 hours
5. Set up automated backups
