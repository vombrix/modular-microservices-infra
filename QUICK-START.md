# Quick Start Guide

Get your complete microservices infrastructure running in 5 minutes!

## 📦 What You're Getting

A production-ready local development environment with:
- **5 modular stacks** communicating via shared network
- **20+ services** including databases, messaging, observability, and more
- **Complete LGTM stack** (Loki, Grafana, Tempo, Prometheus)
- **API Gateway** (Kong) + **Identity** (Keycloak) + **Reverse Proxy** (Nginx)
- **CI/CD** (Jenkins) + **Security scanning** (Trivy)

## ⚡ Prerequisites

```bash
# Verify Docker and Docker Compose
docker --version  # Need 24.0+
docker compose version  # Need 2.20+

# Check system resources
free -h  # Need 8GB+ RAM
df -h    # Need 20GB+ free disk
```

## 🚀 Installation (3 Steps)

### Step 1: Setup Environment

```bash
# Create project directory
mkdir microservices-infra && cd microservices-infra

# Copy all configuration files from artifacts
# (Setup the directory structure as shown in the main README)

# Make scripts executable
chmod +x setup.sh start-all.sh stop-all.sh status.sh
```

### Step 2: Configure

```bash
# Copy environment template
cp .env.example .env

# IMPORTANT: Edit .env and change at minimum:
# - All passwords (search for "password")
# - POSTGRES_PASSWORD
# - MONGO_INITDB_ROOT_PASSWORD
# - REDIS_PASSWORD
# - ELASTIC_PASSWORD
# - KEYCLOAK_ADMIN_PASSWORD
# - GRAFANA_ADMIN_PASSWORD

nano .env  # or use your preferred editor
```

### Step 3: Launch

```bash
# Create network
./setup.sh

# Start all services (this will take 2-3 minutes)
./start-all.sh

# Check status
./status.sh
```

## 🎯 First Steps After Installation

### 1. Access Grafana
```
URL: http://localhost:3000
Username: admin
Password: admin (change in .env)
```

**What to do:**
- Verify datasources are connected (Prometheus, Loki, Tempo)
- Explore pre-configured dashboards
- Create your first dashboard

### 2. Access Portainer
```
URL: http://localhost:9000
```

**What to do:**
- Set admin password on first login
- Explore container management UI
- View logs and stats

### 3. Access Kafka UI
```
URL: http://localhost:8080
```

**What to do:**
- View topics (events, logs, metrics, traces, notifications, user-activity)
- Monitor consumer groups
- Inspect messages

### 4. Access SeaweedFS Filer / S3
```
Filer UI: http://localhost:8888
Master UI: http://localhost:9333
S3 Gateway: http://localhost:8333
Admin User: admin (pass configured in .env)
```

**What to do:**
- Browse buckets and directories in Filer UI
- Monitor volume layout in Master UI
- Upload/download objects via AWS S3 CLI or SDK

### 5. Test Kong Gateway
```bash
# Check Kong is running
curl http://localhost:8001/status

# List configured services
curl http://localhost:8001/services

# Test a route through Kong
curl http://localhost:8000/api/
```

## 🔍 Quick Health Checks

```bash
# All-in-one status
./status.sh

# Individual service checks
docker ps --format "table {{.Names}}\t{{.Status}}"

# Check logs
docker logs postgres --tail 50
docker logs grafana --tail 50

# Test database connections
docker exec postgres psql -U admin -d main_db -c "SELECT version();"
docker exec mongodb mongosh --eval "db.adminCommand('ping')"
docker exec redis redis-cli ping
```

## 📊 Send Test Telemetry

### Send Metrics to OTel Collector
```bash
curl -X POST http://localhost:4318/v1/metrics \
  -H "Content-Type: application/json" \
  -d '{
    "resourceMetrics": [{
      "scopeMetrics": [{
        "metrics": [{
          "name": "test.metric",
          "gauge": {
            "dataPoints": [{
              "asDouble": 42.0,
              "timeUnixNano": "'$(date +%s)000000000'"
            }]
          }
        }]
      }]
    }]
  }'
```

### Send Logs to OTel Collector
```bash
curl -X POST http://localhost:4318/v1/logs \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "'$(date +%s)000000000'",
          "severityText": "INFO",
          "body": {
            "stringValue": "Test log message from curl"
          }
        }]
      }]
    }]
  }'
```

### Send Trace to OTel Collector
```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "scopeSpans": [{
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "test-span",
          "kind": 1,
          "startTimeUnixNano": "'$(date +%s)000000000'",
          "endTimeUnixNano": "'$(($(date +%s) + 1))000000000'"
        }]
      }]
    }]
  }'
```

## 🛠️ Common Operations

### View Logs
```bash
# All logs from a service
docker logs -f grafana

# Last 100 lines
docker logs --tail 100 postgres

# With timestamps
docker logs -f --timestamps kafka
```

### Restart a Service
```bash
cd 01-data
docker compose restart postgres

# Or restart all in stack
docker compose restart
```

### Stop Everything
```bash
# Stop but keep data
./stop-all.sh

# Stop and remove containers (keeps volumes)
./stop-all.sh

# Stop and remove EVERYTHING including data (careful!)
./stop-all.sh --volumes
```

### View Resource Usage
```bash
# Live stats
docker stats

# Specific service
docker stats postgres grafana kafka
```

## 🐛 Troubleshooting

### "Network global-infra not found"
```bash
./setup.sh
```

### "Port already in use"
```bash
# Find what's using the port
sudo lsof -i :8080

# Change port in .env
nano .env
# Change GRAFANA_PORT=3000 to GRAFANA_PORT=3001

# Restart
cd 03-observability && docker compose up -d
```

### "Service unhealthy"
```bash
# Check logs
docker logs <service-name>

# Check health
docker inspect <service-name> | grep -A 10 Health

# Manual health check
docker exec postgres pg_isready -U admin
docker exec elasticsearch curl -f http://localhost:9200/_cluster/health
```

### "Out of memory"
```bash
# Check Docker resources
docker system df

# Clean up
docker system prune -a

# Increase Docker Desktop memory
# Docker Desktop → Settings → Resources → Memory: 8GB+
```

### Services not communicating
```bash
# Verify network
docker network inspect global-infra

# Check service IPs
docker inspect -f '{{.NetworkSettings.Networks.global_infra.IPAddress}}' postgres

# Test connectivity
docker exec grafana ping -c 2 prometheus
```

## 📚 Next Steps

1. **Customize Services**: Edit `docker-compose.yml` files in each stack
2. **Add Your Application**: Create a new service in `01-data/docker-compose.yml`
3. **Configure Kong Routes**: Edit `04-gateway/kong/kong.yml`
4. **Setup Keycloak Realm**: Import realm from `04-gateway/keycloak/realm-export.json`
5. **Create Grafana Dashboards**: Import dashboards or create custom ones
6. **Setup CI/CD Pipeline**: Configure Jenkins jobs
7. **Security Hardening**: Follow `PRODUCTION-HARDENING.md`

## 🔗 Useful Links

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Grafana | http://localhost:3000 | admin/admin |
| Prometheus | http://localhost:9090 | - |
| Kafka UI | http://localhost:8080 | - |
| Kong Admin | http://localhost:8001 | - |
| Keycloak | http://localhost:8080/auth | admin/admin |
| Portainer | http://localhost:9000 | Set on first login |
| SeaweedFS Filer | http://localhost:8888 | - |
| SeaweedFS S3 | http://localhost:8333 | admin (see .env) |
| Jenkins | http://localhost:8080 | admin/admin |

## 💡 Pro Tips

1. **Use aliases for common commands:**
```bash
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlogs='docker logs -f --tail 100'
alias dexec='docker exec -it'
```

2. **Create a tmux session for monitoring:**
```bash
tmux new -s infra
# Split panes and run:
# Pane 1: ./status.sh && watch -n 5 ./status.sh
# Pane 2: docker logs -f grafana
# Pane 3: docker stats
```

3. **Backup before experimenting:**
```bash
# Backup all data
./stop-all.sh --stop-only
tar -czf backup-$(date +%Y%m%d).tar.gz */data/
./start-all.sh
```

## 🆘 Getting Help

- **Check logs first**: `docker logs <service>`
- **Review documentation**: See `README.md` and `PRODUCTION-HARDENING.md`
- **Verify network**: `docker network inspect global-infra`
- **Check resources**: `docker stats`
- **Full restart**: `./stop-all.sh && ./start-all.sh`

---

**Enjoy your production-grade local development infrastructure! 🚀**