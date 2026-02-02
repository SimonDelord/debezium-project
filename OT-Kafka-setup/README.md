# OpenShift / Strimzi Kafka Setup with Debezium CDC

This folder contains the Kafka and Debezium CDC configuration for the SQL Server CDC PoC.

## Components

| File | Description |
|------|-------------|
| `kafka-cluster.yaml` | Kafka cluster CR with KRaft mode enabled |
| `kafka-nodepool.yaml` | KafkaNodePool CR for broker/controller nodes |
| `kafka-connect.yaml` | KafkaConnect CR with Debezium SQL Server plugin (v3.0.0) |
| `debezium-sqlserver-connector.yaml` | KafkaConnector CR for SQL Server CDC |

## Architecture

```
┌─────────────────────────┐
│   MS SQL Server 2022    │
│   <SQL_SERVER_HOST>     │
│   Database: MySimpleDB  │
└───────────┬─────────────┘
            │ CDC (Change Data Capture)
            ▼
┌─────────────────────────┐
│   Debezium Connector    │
│   (KafkaConnect 3.0.0)  │
└───────────┬─────────────┘
            │ Publishes changes
            ▼
┌─────────────────────────┐
│   Kafka Topics          │
│   dbserver1.*           │
└─────────────────────────┘
```

## Configuration Details

### Kafka Cluster
- **Name:** my-cluster
- **Version:** Kafka 4.1.0
- **Mode:** KRaft (no ZooKeeper)
- **Listeners:**
  - `plain` - Port 9092 (no TLS)
  - `tls` - Port 9093 (with TLS)

### Kafka Connect
- **Debezium Version:** 3.0.0.Final (required for Kafka 4.x compatibility)
- **Converters:** StringConverter (for Kafka 4.x compatibility)

### Debezium SQL Server Connector
| Setting | Value |
|---------|-------|
| **SQL Server Host** | `<SQL_SERVER_HOST>` |
| **Port** | 1433 |
| **Database** | MySimpleDB_Tsql |
| **Username** | `<DB_USER>` |
| **Password** | `<DB_PASSWORD>` |
| **Topic Prefix** | dbserver1 |
| **Snapshot Mode** | schema_only |
| **Schema History** | MemorySchemaHistory |

> **Note:** Update the connector YAML with your actual database connection details before deploying.

## Deployment

### Step 1: Deploy Kafka Cluster
```bash
# Create namespace
oc new-project debezium-demo

# Deploy Kafka cluster and node pool
oc apply -f kafka-cluster.yaml
oc apply -f kafka-nodepool.yaml

# Wait for cluster to be ready
oc wait kafka/my-cluster --for=condition=Ready --timeout=300s
```

### Step 2: Deploy Kafka Connect with Debezium
```bash
# Deploy KafkaConnect (this builds the Debezium connector image)
oc apply -f kafka-connect.yaml

# Wait for KafkaConnect to be ready (may take 3-5 minutes for build)
oc wait kafkaconnect/debezium-connect --for=condition=Ready --timeout=600s
```

### Step 3: Enable CDC on SQL Server
Before deploying the connector, enable CDC on your SQL Server database:
```bash
# Run the enable-cdc.sql script on your SQL Server
sqlcmd -S <server> -U <user> -P <password> -d MySimpleDB_Tsql -i ../scripts/enable-cdc.sql
```

### Step 4: Deploy the SQL Server Connector
```bash
# Update the connector YAML with your database credentials first!
# Then deploy the connector configuration
oc apply -f debezium-sqlserver-connector.yaml

# Check connector status
oc get kafkaconnector sqlserver-cdc-new -o yaml
```

## Verify CDC is Working

### Check Connector Status
```bash
# Get connector status
oc get kafkaconnector sqlserver-cdc-new -o jsonpath='{.status.connectorStatus.connector.state}'
# Should return: RUNNING
```

### List Kafka Topics
```bash
# Check created topics (use the correct pod name)
oc exec -it my-cluster-my-pool-0 -- bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list | grep dbserver
```

### Consume CDC Messages
```bash
# Consume messages from the CDC topic
oc exec -it my-cluster-my-pool-0 -- bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic dbserver1.MySimpleDB_Tsql.dbo.truck_locations \
  --from-beginning
```

## Topic Naming Convention

Debezium creates topics with the following pattern:
```
{topic.prefix}.{database}.{schema}.{table}
```

Example:
- `dbserver1.MySimpleDB_Tsql.dbo.truck_locations`

## Kafka 4.x Compatibility Notes

When using Kafka 4.x (KRaft mode), the following configurations are required:

1. **Debezium Version:** Use 3.0.0.Final or later
2. **Schema History:** Use `MemorySchemaHistory` instead of `KafkaSchemaHistory`
3. **Converters:** Use `StringConverter` instead of `JsonConverter`

## Troubleshooting

### Check KafkaConnect Logs
```bash
oc logs -f debezium-connect-connect-0
```

### Check Connector Status
```bash
oc describe kafkaconnector sqlserver-cdc-new
```

### Restart Connector
```bash
oc delete kafkaconnector sqlserver-cdc-new
oc apply -f debezium-sqlserver-connector.yaml
```

### Common Issues

1. **"NoSuchMethodError: KafkaConsumer.poll"** - Version incompatibility. Use Debezium 3.0.0+ with Kafka 4.x
2. **"User does not have access to CDC schema"** - Run enable-cdc.sql on SQL Server first
3. **"db history topic is missing"** - Use MemorySchemaHistory or create a new connector with a different name
