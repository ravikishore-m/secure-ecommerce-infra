## Observability Blueprint

### Metrics
- **Amazon Managed Prometheus (AMP)**: Primary TSDB for Kubernetes + app metrics.
- **Collectors**: ADOT + Prometheus scraping `ServiceMonitor` resources.
- **Dashboards**: Amazon Managed Grafana workspace `ecom-prod`. Dashboards cover:
  - SLOs (availability, latency, error budget burn)
  - Capacity (node/pod utilization, HPA signals)
  - Business KPIs (orders/min, payment success, inventory latency)
- **Alerting**: AMP alert rules forward to SNS → PagerDuty & Slack via AWS Chatbot. Include runbook links.
- **Custom metrics**: Expose throttled request counters (e.g., `http_requests_throttled_per_second`) via Prometheus Adapter so HorizontalPodAutoscalers can scale when 4xx/5xx spikes appear, not just on CPU.

### Logs
- **Ingestion**: Fluent Bit (IRSA-enabled) ships Kubernetes logs + audit events to CloudWatch Logs; CloudWatch subscriptions or exporters can forward to OpenSearch/S3 if needed.
- **Retention**: 30 days (workload logs) / 365 days (audit logs) configurable via Terraform.
- **Correlation**: Structured JSON with request IDs, span IDs, and customer/session metadata.
- **Security**: CloudTrail org trail, VPC Flow Logs, WAF logs stored in the shared-services account.

### Traces
- **Collector**: ADOT (OTLP) exporting to AWS X-Ray + AMP.
- **Sampling**: 10% baseline, 100% for errors (dynamic).
- **Visualization**: X-Ray Service Map + Grafana Tempo data source (optional).

### Synthetic Monitoring
- (Optional) CloudWatch Synthetics canaries hitting `/healthz`, `/orders`, `/payments`. Store scripts alongside this repo and deploy via SAM/Serverless.
- Lightweight curl-based smoke tests run in GitHub Actions after successful Helm deploys (add as needed).

### Incident Management
- Alert routing via AWS Incident Manager → PagerDuty.
- SLA dashboards pinned to Network Operations Center TVs.
- On-call handoff documented weekly; metrics tracked for MTTR, MTTA.

