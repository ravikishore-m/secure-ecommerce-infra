## Observability Blueprint

### Metrics
- **Amazon Managed Prometheus (AMP)**: Primary TSDB for Kubernetes + app metrics.
- **Collectors**: ADOT + Prometheus scraping `ServiceMonitor` resources.
- **Dashboards**: Amazon Managed Grafana workspace `ecom-prod`. Dashboards cover:
  - SLOs (availability, latency, error budget burn)
  - Capacity (node/pod utilization, HPA signals)
  - Business KPIs (orders/min, payment success, inventory latency)
- **Alerting**: AMP alert rules forward to SNS → PagerDuty & Slack via AWS Chatbot. Include runbook links.

### Logs
- **Ingestion**: Fluent Bit DaemonSet with IAM role shipping to CloudWatch Logs, Kinesis Firehose → OpenSearch, and S3 (long-term).
- **Retention**: 30 days in CloudWatch, 365 days in S3 Glacier Deep Archive.
- **Correlation**: Trace/span IDs injected into logs (structured JSON).
- **Security**: CloudTrail org trail, VPC Flow Logs, WAF logs stored centrally.

### Traces
- **Collector**: ADOT (OTLP) exporting to AWS X-Ray + AMP.
- **Sampling**: 10% baseline, 100% for errors (dynamic).
- **Visualization**: X-Ray Service Map + Grafana Tempo data source (optional).

### Synthetic Monitoring
- CloudWatch Synthetics canaries hitting `/healthz`, `/orders`, `/payments`.
- Lambda-backed custom checks for third-party integrations (payment gateways).

### Incident Management
- Alert routing via AWS Incident Manager → PagerDuty.
- SLA dashboards pinned to Network Operations Center TVs.
- On-call handoff documented weekly; metrics tracked for MTTR, MTTA.

