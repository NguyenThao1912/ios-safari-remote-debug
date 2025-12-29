# Google Cloud Platform Deployment Guide

Hướng dẫn deploy ios-safari-remote-debug lên Google Cloud Platform (GCP).

## Yêu cầu

- Google Cloud account
- VM instance với Ubuntu 20.04+ hoặc 22.04+
- SSH access vào VM

## Bước 1: Tạo VM Instance

```bash
# Tạo VM instance
gcloud compute instances create ios-debug-vm \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --tags=http-server,https-server
```

## Bước 2: SSH vào VM

```bash
gcloud compute ssh ios-debug-vm --zone=us-central1-a
```

## Bước 3: Clone repository

```bash
# Cài Git nếu chưa có
sudo apt update
sudo apt install git -y

# Clone repo
git clone <your-repo-url>
cd ios-safari-remote-debug
```

## Bước 4: Chạy setup script

```bash
# Chạy setup script tự động
./setup-gcp.sh
```

Script này sẽ:
- Cài đặt Git, Docker, Docker Compose, Go
- Cấu hình Docker permissions
- Khởi tạo Docker Swarm
- Build Docker image
- Kiểm tra Caddyfile

## Bước 5: Cấu hình Firewall

Mở ports trong GCP Firewall:

```bash
# Tạo firewall rule
gcloud compute firewall-rules create allow-ios-debug \
    --allow tcp:80,tcp:443,tcp:8080,tcp:8443 \
    --source-ranges 0.0.0.0/0 \
    --description "Allow ios-safari-remote-debug ports"
```

Hoặc qua GCP Console:
1. Vào VPC network > Firewall
2. Create Firewall Rule
3. Allow: tcp:80, tcp:443, tcp:8080, tcp:8443
4. Target tags: http-server, https-server

## Bước 6: Cấu hình Caddyfile

```bash
nano Caddyfile
```

Thay `your-domain.com` bằng:
- Domain của bạn (nếu có)
- Hoặc IP của VM instance
- Hoặc `localhost` (để test)

## Bước 7: Deploy Stack

```bash
# Option 1: Dùng menu
./run.sh
# Chọn option 1: Deploy stack

# Option 2: Dùng script
./deploy.sh

# Option 3: Manual
docker build -t ios-safari-remote-debug:latest .
docker stack deploy -c docker-stack.yml ios-safari-remote-debug
```

## Bước 8: Kiểm tra

```bash
# Kiểm tra services
docker stack services ios-safari-remote-debug

# Test access
./test-access.sh

# Xem logs
./view-logs.sh
```

## Truy cập từ bên ngoài

Lấy external IP của VM:

```bash
gcloud compute instances describe ios-debug-vm \
    --zone=us-central1-a \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

Truy cập:
- `http://<EXTERNAL_IP>:8080` (nếu dùng alt-ports)
- `http://<EXTERNAL_IP>` (nếu dùng ports 80/443)

## Troubleshooting

### Permission denied

```bash
# Thêm user vào docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Ports không accessible

```bash
# Kiểm tra firewall
gcloud compute firewall-rules list

# Kiểm tra ports đang listen
sudo netstat -tuln | grep -E '80|443|8080|8443'
```

### Services không start

```bash
# Xem logs
./view-logs.sh

# Hoặc
docker service logs ios-safari-remote-debug_app
docker service logs ios-safari-remote-debug_caddy
```

### Không thể xem logs

```bash
# Export logs ra files
./export-logs.sh

# Xem với --no-follow
./logs.sh all --tail 100 --no-follow
```

## Các lệnh hữu ích

```bash
# Xem status
./status.sh

# Xem logs
./view-logs.sh

# Test access
./test-access.sh

# Stop stack
./stop.sh

# Remove stack
./remove.sh

# Menu chính
./run.sh
```

## Lưu ý

1. **Firewall**: Đảm bảo ports đã mở trong GCP Firewall Rules
2. **Domain**: Nếu dùng domain, cấu hình DNS trỏ về external IP
3. **SSL**: Caddy tự động lấy SSL certificate nếu dùng domain
4. **Logs**: Dùng `--no-follow` để tránh timeout trên cloud
5. **Resources**: Đảm bảo VM có đủ RAM (tối thiểu 2GB)

## Backup và Restore

```bash
# Backup volumes
docker run --rm -v ios-safari-remote-debug_caddy_data:/data \
    -v $(pwd):/backup alpine tar czf /backup/caddy_backup.tar.gz -C /data .

# Restore
docker run --rm -v ios-safari-remote-debug_caddy_data:/data \
    -v $(pwd):/backup alpine tar xzf /backup/caddy_backup.tar.gz -C /data
```

