# Production Hardening Guide

This guide provides critical security and performance configurations for taking this infrastructure to production.

## 🔒 Keycloak Security Hardening

### 1. SSL/TLS Configuration

**Enable HTTPS Required:**
```bash
# In docker-compose.yml environment
KC_HOSTNAME_STRICT_HTTPS: "true"
KC_HTTPS_CERTIFICATE_FILE: /opt/keycloak/conf/server.crt
KC_HTTPS_CERTIFICATE_KEY_FILE: /opt/keycloak/conf/server.key
```

**Generate Production Certificates:**
```bash
# Use Let's Encrypt or your CA
certbot certonly --standalone -d keycloak.yourdomain.com

# Or generate self-signed for internal use
openssl req -newkey rsa:4096 -nodes -keyout server.key \
  -x509 -days 365 -out server.crt \
  -subj "/CN=keycloak.yourdomain.com"
```

### 2. Database Security

**Use Strong Passwords:**
```env
KEYCLOAK_DB_PASSWORD=$(openssl rand -base64 32)
```

**Enable SSL for Database Connection:**
```bash
KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak?ssl=true&sslmode=require
```

**Separate Database Instance:**
- Use dedicated PostgreSQL instance for Keycloak
- Enable connection pooling
- Implement regular backups

### 3. Authentication & Access Control

**Password Policies:**
```
Navigate to: Realm Settings → Security Defenses → Password Policy
- Minimum length: 12 characters
- Require uppercase: Yes
- Require lowercase: Yes
- Require digits: Yes
- Require special characters: Yes
- Not recently used: 3
- Expire password: 90 days
```

**Brute Force Detection:**
```
Realm Settings → Security Defenses → Brute Force Detection
- Enabled: Yes
- Permanent lockout: No
- Max login failures: 5
- Wait increment: 60 seconds
- Quick login check: 1000ms
- Minimum quick login wait: 60 seconds
```

**Multi-Factor Authentication:**
```
Authentication → Flows
- Copy Browser flow
- Add OTP as required step
- Bind to Browser Flow
```

### 4. Token Configuration

**Optimize Token Lifetimes:**
```
Realm Settings → Tokens
- Access Token Lifespan: 5 minutes
- Access Token Lifespan For Implicit Flow: 15 minutes
- Client login timeout: 5 minutes
- Login timeout: 30 minutes
- Login action timeout: 5 minutes
- SSO Session Idle: 30 minutes
- SSO Session Max: 10 hours
```

**Enable Token Revocation:**
```bash
# Enable token revocation checking
KC_FEATURES: token-exchange,admin-fine-grained-authz,token-revocation
```

### 5. Network Security

**Restrict Admin Access:**
```nginx
# In Nginx config
location /auth/admin {
    allow 10.0.0.0/8;      # Internal network only
    allow 172.16.0.0/12;
    deny all;
    proxy_pass http://keycloak:8080;
}
```

**Enable CORS Properly:**
```
Client Settings → Web Origins
- Add only trusted domains
- Never use "*" in production
```

### 6. Monitoring & Auditing

**Enable Event Listeners:**
```
Realm Settings → Events → Event Listeners
- Add: jboss-logging
- Add: email
```

**Configure Event Storage:**
```
Events → Event Configs
- Login Events Settings:
  - Save Events: ON
  - Expiration: 90 days
  - Clear events: Weekly
- Admin Events Settings:
  - Save Events: ON
  - Include Representation: ON
```

### 7. Performance Optimization

**Connection Pool Settings:**
```bash
KC_DB_POOL_INITIAL_SIZE: 20
KC_DB_POOL_MIN_SIZE: 10
KC_DB_POOL_MAX_SIZE: 100
```

**Caching Configuration:**
```bash
KC_CACHE: ispn
KC_CACHE_STACK: kubernetes
KC_CACHE_CONFIG_FILE: /opt/keycloak/conf/cache-ispn.xml
```

**JVM Tuning:**
```bash
JAVA_OPTS_APPEND: >-
  -Xms2g -Xmx2g
  -XX:MetaspaceSize=256m
  -XX:MaxMetaspaceSize=512m
  -XX:+UseG1GC
  -XX:MaxGCPauseMillis=100
  -Djava.net.preferIPv4Stack=true
```

---

## 🔍 Elasticsearch Security Hardening

### 1. Enable X-Pack Security

**Update docker-compose.yml:**
```yaml
environment:
  - xpack.security.enabled=true
  - xpack.security.enrollment.enabled=true
  - ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
  
  # SSL Configuration
  - xpack.security.http.ssl.enabled=true
  - xpack.security.http.ssl.key=/usr/share/elasticsearch/config/certs/elastic.key
  - xpack.security.http.ssl.certificate=/usr/share/elasticsearch/config/certs/elastic.crt
  - xpack.security.http.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/ca.crt
  
  # Transport SSL
  - xpack.security.transport.ssl.enabled=true
  - xpack.security.transport.ssl.verification_mode=certificate
  - xpack.security.transport.ssl.key=/usr/share/elasticsearch/config/certs/elastic.key
  - xpack.security.transport.ssl.certificate=/usr/share/elasticsearch/config/certs/elastic.crt
  - xpack.security.transport.ssl.certificate_authorities=/usr/share/elasticsearch/config/certs/ca.crt
```

### 2. Generate Certificates

**Using elasticsearch-certutil:**
```bash
# Create CA
docker exec elasticsearch \
  bin/elasticsearch-certutil ca \
  --out /usr/share/elasticsearch/config/certs/elastic-stack-ca.p12 \
  --pass ""

# Create certificates
docker exec elasticsearch \
  bin/elasticsearch-certutil cert \
  --ca /usr/share/elasticsearch/config/certs/elastic-stack-ca.p12 \
  --ca-pass "" \
  --out /usr/share/elasticsearch/config/certs/elastic-certificates.p12 \
  --pass ""

# Extract PEM format
docker exec elasticsearch \
  openssl pkcs12 -in /usr/share/elasticsearch/config/certs/elastic-certificates.p12 \
  -out /usr/share/elasticsearch/config/certs/elastic.crt -nokeys -nodes

docker exec elasticsearch \
  openssl pkcs12 -in /usr/share/elasticsearch/config/certs/elastic-certificates.p12 \
  -out /usr/share/elasticsearch/config/certs/elastic.key -nocerts -nodes
```

### 3. Role-Based Access Control (RBAC)

**Create Custom Roles:**
```bash
# Application read-only role
curl -X POST "https://elastic:${ELASTIC_PASSWORD}@localhost:9200/_security/role/app_reader" \
  -H 'Content-Type: application/json' -d'
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": ["app-logs-*"],
      "privileges": ["read", "view_index_metadata"]
    }
  ]
}'

# Application writer role
curl -X POST "https://elastic:${ELASTIC_PASSWORD}@localhost:9200/_security/role/app_writer" \
  -H 'Content-Type: application/json' -d'
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": ["app-logs-*"],
      "privileges": ["create_index", "write", "read", "view_index_metadata"]
    }
  ]
}'
```

**Create Service Accounts:**
```bash
# Create user for log ingestion
curl -X POST "https://elastic:${ELASTIC_PASSWORD}@localhost:9200/_security/user/log_ingest" \
  -H 'Content-Type: application/json' -d'
{
  "password" : "'"$(openssl rand -base64 24)"'",
  "roles" : ["app_writer"],
  "full_name" : "Log Ingestion Service"
}'
```

### 4. Network Security

**Bind to Specific Interface:**
```yaml
environment:
  - network.host=0.0.0.0
  - network.publish_host=elasticsearch
  - discovery.seed_hosts=["elasticsearch"]
```

**Enable IP Filtering:**
```yaml
# In elasticsearch.yml
xpack.security.transport.filter.enabled: true
xpack.security.transport.filter.allow: ["10.0.0.0/8", "172.16.0.0/12"]
xpack.security.transport.filter.deny: "_all"
```

### 5. Audit Logging

**Enable Audit Trail:**
```yaml
environment:
  - xpack.security.audit.enabled=true
  - xpack.security.audit.logfile.events.include=["access_denied", "authentication_failed", "connection_denied", "tampered_request", "run_as_denied"]
  - xpack.security.audit.logfile.events.emit_request_body=true
```

### 6. Index Lifecycle Management (ILM)

**Configure ILM Policy:**
```bash
curl -X PUT "https://elastic:${ELASTIC_PASSWORD}@localhost:9200/_ilm/policy/logs_policy" \
  -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_age": "7d",
            "max_size": "50gb"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": {
            "number_of_shards": 1
          },
          "forcemerge": {
            "max_num_segments": 1
          }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "freeze": {}
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}'
```

### 7. Performance Optimization

**JVM Heap Sizing:**
```yaml
environment:
  # Set to 50% of available RAM, max 32GB
  - ES_JAVA_OPTS=-Xms4g -Xmx4g -XX:+UseG1GC
```

**Index Settings:**
```bash
# Optimize for write-heavy workloads
curl -X PUT "https://elastic:${ELASTIC_PASSWORD}@localhost:9200/_template/logs_template" \
  -H 'Content-Type: application/json' -d'
{
  "index_patterns": ["logs-*"],
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "refresh_interval": "30s",
    "translog.durability": "async",
    "translog.sync_interval": "5s"
  }
}'
```

**Circuit Breakers:**
```yaml
# In elasticsearch.yml
indices.breaker.total.limit: 70%
indices.breaker.request.limit: 40%
indices.breaker.fielddata.limit: 40%
```

### 8. Backup Strategy

**Snapshot Repository:**
```bash
# Configure S3 snapshot repository
curl -X PUT "https://elastic:${ELASTIC_PASSWORD}@localhost:9200/_snapshot/s3_repository" \
  -H 'Content-Type: application/json' -d'
{
  "type": "s3",
  "settings": {
    "bucket": "elasticsearch-backups",
    "region": "us-east-1",
    "base_path": "snapshots",
    "compress": true
  }
}'

# Create automated snapshot policy
curl -X PUT "https://elastic:${ELASTIC_PASSWORD}@localhost:9200/_slm/policy/daily-snapshots" \
  -H 'Content-Type: application/json' -d'
{
  "schedule": "0 1 * * *",
  "name": "<daily-snap-{now/d}>",
  "repository": "s3_repository",
  "config": {
    "indices": ["*"],
    "ignore_unavailable": true,
    "include_global_state": false
  },
  "retention": {
    "expire_after": "30d",
    "min_count": 7,
    "max_count": 30
  }
}'
```

---

## 📊 General Production Checklist

### Infrastructure
- [ ] Use orchestration platform (Kubernetes/Docker Swarm)
- [ ] Implement service mesh (Istio/Linkerd)
- [ ] Configure auto-scaling policies
- [ ] Set up load balancing
- [ ] Enable health checks and readiness probes
- [ ] Implement circuit breakers

### Security
- [ ] Change all default credentials
- [ ] Use secrets management (Vault, AWS Secrets Manager)
- [ ] Enable mutual TLS (mTLS) between services
- [ ] Implement network policies
- [ ] Regular security scanning (Trivy, Clair)
- [ ] Enable audit logging across all services

### Observability
- [ ] Configure alert rules in Prometheus
- [ ] Set up on-call rotation (PagerDuty, Opsgenie)
- [ ] Enable distributed tracing on all services
- [ ] Configure log retention policies
- [ ] Set up dashboards for business metrics
- [ ] Implement SLI/SLO monitoring

### High Availability
- [ ] Multi-region deployment
- [ ] Database replication (PostgreSQL streaming replication)
- [ ] Redis Sentinel or Redis Cluster
- [ ] Elasticsearch cluster (minimum 3 nodes)
- [ ] Kafka cluster (minimum 3 brokers)
- [ ] MinIO distributed mode

### Disaster Recovery
- [ ] Automated backup schedule
- [ ] Test restore procedures quarterly
- [ ] Document recovery time objectives (RTO)
- [ ] Document recovery point objectives (RPO)
- [ ] Maintain off-site backups
- [ ] Create runbooks for common incidents

### Performance
- [ ] CDN for static assets
- [ ] Database query optimization
- [ ] Connection pooling
- [ ] Caching strategy (Redis, CDN)
- [ ] Rate limiting and throttling
- [ ] Request/response compression

### Compliance
- [ ] Data encryption at rest
- [ ] Data encryption in transit
- [ ] GDPR compliance (if applicable)
- [ ] PCI-DSS compliance (if handling payments)
- [ ] Regular penetration testing
- [ ] Security incident response plan

---

## 🚀 Migration Path: Dev → Production

### Phase 1: Infrastructure
1. Deploy to staging environment
2. Load testing with realistic traffic
3. Performance tuning
4. Security hardening

### Phase 2: Data
1. Database migration testing
2. Backup/restore validation
3. Data encryption implementation
4. Replication setup

### Phase 3: Observability
1. Alert configuration
2. Dashboard setup
3. Log aggregation testing
4. Trace sampling optimization

### Phase 4: Go-Live
1. Blue-green deployment
2. Traffic migration (10% → 50% → 100%)
3. Monitoring and validation
4. Rollback plan ready

---

## 📚 Additional Resources

- [Keycloak Server Administration](https://www.keycloak.org/docs/latest/server_admin/)
- [Elasticsearch Security](https://www.elastic.co/guide/en/elasticsearch/reference/current/secure-cluster.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [12-Factor App Methodology](https://12factor.net/)