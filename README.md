# Production-Grade Modular Microservices Infrastructure

A complete, modular Docker Compose infrastructure for local development featuring 5 distinct domain stacks that communicate via a shared external network.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Technology Stack](#technology-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Service Access](#service-access)
- [Management](#management)
- [Troubleshooting](#troubleshooting)
- [Production Considerations](#production-considerations)

## 🏗️ Architecture Overview

The infrastructure is split into 5 modular stacks with **centralized database architecture**:

1. **Data Layer** (`01-data/`) - **Centralized PostgreSQL**, MongoDB, Redis, Elasticsearch, MinIO
2. **Messaging Layer** (`02-messaging/`) - Kafka (KRaft mode - ZooKeeper-free)
3. **Observability Layer** (`03-observability/`) - LGTM stack (Loki, Grafana, Tempo, Prometheus)
4. **Gateway Layer** (`04-gateway/`) - Kong (DB-backed), Keycloak, Nginx
5. **Operations Layer** (`05-ops/`) - Jenkins, Portainer, Trivy

All services communicate through a shared Docker network: `global-infra`

### Key Architectural Features
- **Centralized PostgreSQL**: Single database instance serves Keycloak, Kong, and applications
- **Dynamic Initialization**: Database setup via bash script with environment variables
- **DB-Backed Kong**: Full Admin API capabilities with PostgreSQL persistence

## 🛠️ Technology Stack

### Data & Storage
- **PostgreSQL 15** - **Centralized database** (serves Keycloak, Kong, applications)
- **MongoDB 6** - Document database
- **Redis 7** - In-memory cache & session store
- **Elasticsearch 8** - Search & analytics engine
- **MinIO** - S3-compatible object storage

### Messaging
- **Apache Kafka 3.6+** - Event streaming platform (KRaft mode - ZooKeeper-free)
- **Kafka UI** - Web interface for Kafka

### Observability (LGTM Stack)
- **Prometheus** - Metrics collection & storage
- **Loki** - Log aggregation
- **Tempo** - Distributed tracing
- **Grafana** - Unified visualization
- **OpenTelemetry Collector** - Telemetry pipeline

### Gateway & Identity
- **Kong 3.4** - API Gateway (**DB-backed mode** with PostgreSQL)
- **Keycloak 23** - Identity & Access Management
- **Nginx** - Reverse proxy & load balancer

### Operations
- **Jenkins** - CI/CD automation
- **Portainer** - Container management UI
- **Trivy** - Security vulnerability scanner
- **Semgrep** - Static analysis tool

## ✅ Prerequisites

- Docker Engine 24.0+ 
- Docker Compose 2.20+
- 8GB+ RAM recommended
- 20GB+ free disk space
- Linux/macOS/Windows with WSL2

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone <your-repo>
cd microservices-infra

# 2. Copy and configure environment variables
cp .env.example .env
# Edit .env with your preferred settings

# 3. Make setup script executable and run
chmod +x setup.sh
./setup.sh

# 4. Start services in order
cd 01-data && docker compose up -d
cd ../02-messaging && docker compose up -d
cd ../03-observability && docker compose up -d
cd ../04-gateway && docker compose up -d
cd ../05-ops && docker compose up -d

# 5. Verify all services
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## 📚 Detailed Setup

### Step 1: Environment Configuration

Edit the root `.env` file to customize:
- Database credentials
- Service versions
- Port mappings
- Resource limits

### Step 2: Network Setup

```bash
./setup.sh
```

This creates the `global-infra` network with subnet `172.20.0.0/16`.

### Step 3: Start Services by Layer

**Data Layer First:**
```bash
cd 01-data
docker compose up -d
docker compose logs -f  # Watch startup logs
```

Wait for health checks to pass, then proceed to next layer.

**Messaging Layer:**
```bash
cd ../02-messaging
docker compose up -d
```

**Observability Layer:**
```bash
cd ../03-observability
docker compose up -d
```

**Gateway Layer:**
```bash
cd ../04-gateway
docker compose up -d
```

**Operations Layer:**
```bash
cd ../05-ops
docker compose up -d
```

### Step 4: Verify Installation

```bash
# Check all containers
docker ps -a

# Check network connectivity
docker network inspect global-infra

# Test key services
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3000/api/health # Grafana
curl http://localhost:8001            # Kong Admin
```

## 🌐 Service Access

### Data Services
- **PostgreSQL**: `localhost:5432` (user: admin, pass: see .env)
- **MongoDB**: `localhost:27017` (user: mongoadmin)
- **Redis**: `localhost:6379` (pass: see .env)
- **Elasticsearch**: `http://localhost:9200`
- **MinIO Console**: `http://localhost:9001` (user: minioadmin)

### Messaging
- **Kafka**: `localhost:9092` (internal), `localhost:29092` (external)
- **Kafka Controller**: `localhost:9093` (KRaft metadata)
- **Kafka UI**: `http://localhost:8080`

### Observability
- **Grafana**: `http://localhost:3000` (admin/admin)
- **Prometheus**: `http://localhost:9090`
- **Loki**: `http://localhost:3100`
- **Tempo**: `http://localhost:3200`
- **OTel Collector**: gRPC `localhost:4317`, HTTP `localhost:4318`

### Gateway
- **Kong Proxy**: `http://localhost:8000`
- **Kong Admin API**: `http://localhost:8001`
- **Kong Admin GUI**: `http://localhost:8002`
- **Keycloak**: `http://localhost:8080/auth`
- **Nginx**: `http://localhost:80`

### Operations
- **Jenkins**: `http://localhost:8080`
- **Portainer**: `http://localhost:9000`
- **Trivy Server**: `http://localhost:8082`

## 🔧 Management

### Starting/Stopping Services

```bash
# Stop all services
for dir in 05-ops 04-gateway 03-observability 02-messaging 01-data; do
    cd $dir && docker compose down && cd ..
done

# Start all services
for dir in 01-data 02-messaging 03-observability 04-gateway 05-ops; do
    cd $dir && docker compose up -d && cd ..
done

# Restart specific service
cd 01-data
docker compose restart postgres
```

### Viewing Logs

```bash
# All logs from a stack
cd 03-observability
docker compose logs -f

# Specific service logs
docker compose logs -f prometheus

# Follow logs with timestamps
docker compose logs -f --timestamps prometheus
```

### Scaling Services

```bash
# Scale Kafka consumers (if configured)
cd 02-messaging
docker compose up -d --scale kafka-consumer=3
```

### Backup & Restore

**PostgreSQL Backup:**
```bash
docker exec postgres pg_dump -U admin main_db > backup.sql
```

**PostgreSQL Restore:**
```bash
cat backup.sql | docker exec -i postgres psql -U admin main_db
```

**MongoDB Backup:**
```bash
docker exec mongodb mongodump --out /data/backup
docker cp mongodb:/data/backup ./mongodb-backup
```

## 🐛 Troubleshooting

### Services Won't Start

```bash
# Check container logs
docker compose logs <service-name>

# Verify network
docker network inspect global-infra

# Check resource usage
docker stats

# Verify ports not in use
netstat -tulpn | grep LISTEN
```

### Network Issues

```bash
# Recreate network
docker network rm global-infra
./setup.sh

# Restart Docker daemon
sudo systemctl restart docker
```

### Database Connection Errors

```bash
# Check if database is ready
docker exec postgres pg_isready -U admin

# View PostgreSQL logs
docker logs postgres --tail 100

# Test connection
docker exec -it postgres psql -U admin -d main_db
```

### Performance Issues

```bash
# Check resource limits
docker stats

# Increase memory for Elasticsearch
# Edit docker-compose.yml: ES_JAVA_OPTS=-Xms2g -Xmx2g

# Clean up unused resources
docker system prune -a --volumes
```

## 🔒 Production Considerations

### Security Hardening

1. **Change all default passwords** in `.env`
2. **Enable SSL/TLS** for all services
3. **Configure authentication** on Kong routes
4. **Enable Keycloak security features**:
   - SSL required
   - Strong password policies
   - Multi-factor authentication
5. **Elasticsearch security**:
   - Enable X-Pack security
   - Configure TLS
   - Set up role-based access control
6. **Network isolation**:
   - Use internal networks for backend services
   - Expose only necessary ports
7. **Secrets management**:
   - Use Docker secrets or external vault
   - Never commit `.env` to version control

### Performance Optimization

1. **Resource allocation**:
   - Tune JVM heap sizes
   - Configure connection pools
   - Set appropriate worker counts

2. **Database optimization**:
   - Configure PostgreSQL shared_buffers
   - Set appropriate MongoDB cache size
   - Tune Redis maxmemory policies

3. **Observability tuning**:
   - Adjust scrape intervals
   - Configure retention policies
   - Enable metric relabeling

### High Availability

- Use Docker Swarm or Kubernetes for production
- Implement database replication
- Configure load balancing
- Set up health checks and auto-restart policies
- Implement backup strategies

### Monitoring

- Set up alerts in Prometheus/Grafana
- Configure log retention in Loki
- Enable distributed tracing
- Monitor resource usage
- Set up uptime monitoring

## 📖 Additional Resources

- [Kong Documentation](https://docs.konghq.com/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Grafana Tutorials](https://grafana.com/tutorials/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)

## 🤝 Contributing

Contributions are welcome! Please read the contributing guidelines before submitting PRs.

## 📄 License

MIT License - See LICENSE file for details