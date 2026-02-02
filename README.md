# Debezium PoC

A Proof of Concept demonstrating Change Data Capture (CDC) using Debezium with MS SQL Server, replicating data across Kafka clusters using MirrorMaker2.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    OT ENVIRONMENT                                        │
│                                  (debezium-demo namespace)                               │
│                                                                                          │
│  ┌──────────────────┐       ┌──────────────────┐       ┌──────────────────────────┐    │
│  │  MS SQL Server   │       │    Debezium      │       │     Kafka Cluster        │    │
│  │     2022         │       │   Connector      │       │      (my-cluster)        │    │
│  │                  │       │                  │       │                          │    │
│  │ ┌──────────────┐ │  CDC  │  ┌────────────┐  │       │  ┌────────────────────┐  │    │
│  │ │ MySimpleDB   │ │ ────► │  │ SqlServer  │  │ ────► │  │ dbserver1.*        │  │    │
│  │ │ _Tsql        │ │ :1433 │  │ Connector  │  │ :9092 │  │ topics             │  │    │
│  │ │              │ │       │  │ (v3.0.0)   │  │       │  └────────────────────┘  │    │
│  │ │ truck_       │ │       │  └────────────┘  │       │                          │    │
│  │ │ locations    │ │       │                  │       │  Listeners:              │    │
│  │ └──────────────┘ │       │  KafkaConnect    │       │   - plain: 9092          │    │
│  └──────────────────┘       └──────────────────┘       │   - tls:   9093          │    │
│                                                         └──────────────────────────┘    │
│                                                                      │                  │
│                                                                      │                  │
│                                                         ┌────────────▼─────────────┐    │
│                                                         │     MirrorMaker2         │    │
│                                                         │    (my-mm2-cluster)      │    │
│                                                         │                          │    │
│                                                         │  cluster-a ──► cluster-b │    │
│                                                         │  (source)      (target)  │    │
│                                                         └────────────┬─────────────┘    │
└──────────────────────────────────────────────────────────────────────┼──────────────────┘
                                                                       │
                                                                       │ :9094 (external)
                                                                       │ LoadBalancer
                                                                       ▼
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                                    IT ENVIRONMENT                                         │
│                                  (it-kafka-demo namespace)                                │
│                                                                                           │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐  │
│  │                         Kafka Cluster (my-cluster)                                  │  │
│  │                              3 Replicas (HA)                                        │  │
│  │                                                                                     │  │
│  │   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐                        │  │
│  │   │   Node 0    │      │   Node 1    │      │   Node 2    │                        │  │
│  │   │  Broker +   │      │  Broker +   │      │  Broker +   │                        │  │
│  │   │ Controller  │      │ Controller  │      │ Controller  │                        │  │
│  │   │   100Gi     │      │   100Gi     │      │   100Gi     │                        │  │
│  │   └─────────────┘      └─────────────┘      └─────────────┘                        │  │
│  │                                                                                     │  │
│  │   Listeners:                          Mirrored Topics:                             │  │
│  │     - plain:    9092 (internal)         - cluster-a.dbserver1.*                    │  │
│  │     - tls:      9093 (internal)         - cluster-a.sqlserver.*                    │  │
│  │     - external: 9094 (LoadBalancer)     - mirrormaker2-cluster-*                   │  │
│  └────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                           │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
1. INSERT/UPDATE/DELETE on SQL Server
         │
         ▼
2. Debezium CDC Connector captures changes (port 1433)
         │
         ▼
3. Published to OT Kafka topic: dbserver1.MySimpleDB_Tsql.dbo.truck_locations
         │
         ▼
4. MirrorMaker2 replicates to IT Kafka (port 9094)
         │
         ▼
5. Available on IT Kafka topic: cluster-a.dbserver1.MySimpleDB_Tsql.dbo.truck_locations
```

## Components

### MS SQL Server 2022

| Property | Value |
|----------|-------|
| Database | MySimpleDB_Tsql |
| Table | dbo.truck_locations |
| CDC | Enabled |
| Port | 1433 |

**Table Schema:**
```sql
CREATE TABLE truck_locations (
    id        INT IDENTITY(1,1) PRIMARY KEY,
    truck_id  INT NOT NULL,
    time      DATETIME2 NOT NULL,
    latitude  DECIMAL(10,7) NOT NULL,
    longitude DECIMAL(10,7) NOT NULL
);
```

### OT Kafka Cluster (debezium-demo)

| Property | Value |
|----------|-------|
| Name | my-cluster |
| Version | Kafka 4.1.0 |
| Mode | KRaft (no ZooKeeper) |
| Replicas | 1 |
| Listeners | plain (9092), tls (9093) |

### Debezium Connector

| Property | Value |
|----------|-------|
| Version | 3.0.0.Final |
| Connector Class | SqlServerConnector |
| Topic Prefix | dbserver1 |
| Snapshot Mode | schema_only |
| Schema History | MemorySchemaHistory |

### MirrorMaker2

| Property | Value |
|----------|-------|
| Source Cluster | cluster-a (OT internal :9092) |
| Target Cluster | cluster-b (IT external :9094) |
| Topics Pattern | .* (all topics) |
| Groups Pattern | .* (all consumer groups) |

### IT Kafka Cluster (it-kafka-demo)

| Property | Value |
|----------|-------|
| Name | my-cluster |
| Version | Kafka 4.1.0 |
| Mode | KRaft (no ZooKeeper) |
| Replicas | 3 (High Availability) |
| Listeners | plain (9092), tls (9093), external (9094) |
| Storage | 100Gi per node (gp3-csi) |
| Replication Factor | 3 |
| Min ISR | 2 |

## Project Structure

```
debezium-PoC/
├── README.md                    # This file
│
├── OT-Kafka-setup/              # OT Environment Configuration
│   ├── README.md
│   ├── kafka-cluster.yaml       # Kafka CR (1 replica)
│   ├── kafka-nodepool.yaml      # KafkaNodePool CR
│   ├── kafka-connect.yaml       # KafkaConnect with Debezium
│   ├── kafka-console.yaml       # AMQ Streams Console
│   ├── kafka-mirrormaker2.yaml  # MirrorMaker2 CR
│   └── debezium-sqlserver-connector.yaml
│
├── IT-Kafka-setup/              # IT Environment Configuration
│   ├── README.md
│   ├── kafka-cluster.yaml       # Kafka CR (3 replicas, external listener)
│   ├── kafka-nodepool.yaml      # KafkaNodePool CR
│   └── kafka-console.yaml       # AMQ Streams Console
│
└── scripts/                     # SQL Scripts
    ├── enable-cdc.sql           # Enable CDC on SQL Server
    ├── insert-10-rows.sql       # Test data (10 rows)
    └── insert-100-rows.sql      # Test data (100 rows)
```

## Quick Start

### 1. Setup SQL Server Database

```bash
# Run on SQL Server to create database and enable CDC
sqlcmd -S <server> -U <user> -P <password> -i scripts/enable-cdc.sql
```

### 2. Deploy OT Kafka Cluster

```bash
oc new-project debezium-demo

# Deploy Kafka
oc apply -f OT-Kafka-setup/kafka-cluster.yaml
oc apply -f OT-Kafka-setup/kafka-nodepool.yaml

# Deploy Kafka Connect with Debezium
oc apply -f OT-Kafka-setup/kafka-connect.yaml

# Wait for build to complete, then deploy connector
oc apply -f OT-Kafka-setup/debezium-sqlserver-connector.yaml
```

### 3. Deploy IT Kafka Cluster

```bash
oc new-project it-kafka-demo

# Deploy Kafka (3 replicas)
oc apply -f IT-Kafka-setup/kafka-cluster.yaml
oc apply -f IT-Kafka-setup/kafka-nodepool.yaml
```

### 4. Deploy MirrorMaker2

```bash
# Update cluster-b bootstrap server in kafka-mirrormaker2.yaml
oc apply -f OT-Kafka-setup/kafka-mirrormaker2.yaml -n debezium-demo
```

### 5. Verify Data Flow

```bash
# Insert test data
sqlcmd -S <server> -U <user> -P <password> -d MySimpleDB_Tsql -i scripts/insert-10-rows.sql

# Check OT Kafka topic
oc exec my-cluster-my-pool-0 -n debezium-demo -- \
  bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic dbserver1.MySimpleDB_Tsql.dbo.truck_locations --from-beginning

# Check IT Kafka topic (mirrored)
oc exec my-cluster-my-pool-0 -n it-kafka-demo -- \
  bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic cluster-a.dbserver1.MySimpleDB_Tsql.dbo.truck_locations --from-beginning
```

## Port Reference

| Component | Port | Protocol | Description |
|-----------|------|----------|-------------|
| SQL Server | 1433 | TCP | Database connection |
| Kafka (internal) | 9092 | TCP | Plain listener (no TLS) |
| Kafka (internal) | 9093 | TCP | TLS listener |
| Kafka (external) | 9094 | TCP | LoadBalancer (IT cluster) |
| Kafka Connect | 8083 | HTTP | REST API |

## Kafka 4.x Compatibility Notes

When using Kafka 4.x (KRaft mode):

1. **Debezium Version:** Use 3.0.0.Final or later
2. **Schema History:** Use `MemorySchemaHistory` instead of `KafkaSchemaHistory`
3. **Converters:** Use `StringConverter` instead of `JsonConverter`

## Troubleshooting

### Check Debezium Connector Status
```bash
oc get kafkaconnector -n debezium-demo
oc describe kafkaconnector sqlserver-cdc-new -n debezium-demo
```

### Check MirrorMaker2 Status
```bash
oc get kafkamirrormaker2 -n debezium-demo
oc logs -f <mm2-pod> -n debezium-demo
```

### List Topics on IT Cluster
```bash
oc exec my-cluster-my-pool-0 -n it-kafka-demo -- \
  bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## License

This project is for demonstration purposes.
