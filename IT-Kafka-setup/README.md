# IT Kafka Setup - AMQ Streams / Strimzi

This folder contains the Kafka configuration for the IT environment.

## Components

| File | Description |
|------|-------------|
| `kafka-cluster.yaml` | Kafka cluster CR with KRaft mode (3 replicas) |
| `kafka-nodepool.yaml` | KafkaNodePool CR with 3 broker/controller nodes |
| `kafka-console.yaml` | AMQ Streams Console for monitoring |

## Architecture

```
┌─────────────────────────────────────────────┐
│           Kafka Cluster (KRaft)             │
│                my-cluster                   │
├─────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
│  │ Node 0  │  │ Node 1  │  │ Node 2  │     │
│  │ Broker  │  │ Broker  │  │ Broker  │     │
│  │ Ctrl    │  │ Ctrl    │  │ Ctrl    │     │
│  │ 100Gi   │  │ 100Gi   │  │ 100Gi   │     │
│  └─────────┘  └─────────┘  └─────────┘     │
├─────────────────────────────────────────────┤
│  Listeners:                                 │
│    - plain:    9092 (internal, no TLS)      │
│    - tls:      9093 (internal, with TLS)    │
│    - external: 9094 (loadbalancer, no TLS)  │
└─────────────────────────────────────────────┘
```

## Configuration Details

### Kafka Cluster
- **Name:** my-cluster
- **Namespace:** it-kafka-demo
- **Version:** Kafka 4.1.0
- **Mode:** KRaft (no ZooKeeper)
- **Replicas:** 3 (high availability)

### Listeners
| Name | Port | Type | TLS | Description |
|------|------|------|-----|-------------|
| plain | 9092 | internal | No | Internal cluster access |
| tls | 9093 | internal | Yes | Internal secure access |
| external | 9094 | loadbalancer | No | External access via AWS ELB |

### Replication Settings (Production-grade)
| Setting | Value |
|---------|-------|
| default.replication.factor | 3 |
| min.insync.replicas | 2 |
| offsets.topic.replication.factor | 3 |
| transaction.state.log.replication.factor | 3 |
| transaction.state.log.min.isr | 2 |

### Storage
- **Type:** Persistent Claim
- **Size:** 100Gi per node
- **Storage Class:** gp3-csi (AWS EBS)

## Deployment

### Step 1: Create Namespace
```bash
oc new-project it-kafka-demo
```

### Step 2: Deploy Kafka Cluster
```bash
# Deploy Kafka cluster and node pool
oc apply -f kafka-cluster.yaml
oc apply -f kafka-nodepool.yaml

# Wait for cluster to be ready
oc wait kafka/my-cluster --for=condition=Ready --timeout=600s -n it-kafka-demo
```

### Step 3: Deploy Console (Optional)
```bash
# Update hostname in kafka-console.yaml first
oc apply -f kafka-console.yaml
```

## Verify Deployment

```bash
# Check Kafka cluster status
oc get kafka -n it-kafka-demo

# Check node pool status
oc get kafkanodepool -n it-kafka-demo

# Check pods
oc get pods -n it-kafka-demo

# List topics
oc exec -it my-cluster-my-pool-0 -n it-kafka-demo -- \
  bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## External Access

The external listener creates an AWS LoadBalancer. Get the bootstrap address:

```bash
oc get kafka my-cluster -n it-kafka-demo -o jsonpath='{.status.listeners[?(@.name=="external")].bootstrapServers}'
```

Connect from outside the cluster:
```bash
kafka-console-consumer.sh \
  --bootstrap-server <EXTERNAL_BOOTSTRAP_ADDRESS>:9094 \
  --topic <TOPIC_NAME>
```

## Differences from OT Environment

| Setting | OT (debezium-demo) | IT (it-kafka-demo) |
|---------|-------------------|-------------------|
| Replicas | 1 | **3** |
| Replication Factor | 1 | **3** |
| Min ISR | 1 | **2** |
| External Listener | No | **Yes (9094)** |
| Storage Class | default | **gp3-csi** |
