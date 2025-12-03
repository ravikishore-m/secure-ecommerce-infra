## Disaster Recovery Runbook

### Objectives
- **RTO**: < 30 min for app tier, < 2 hrs for data tier
- **RPO**: < 5 min (prod) via cross-region replica + PITR

### Prerequisites
- Velero backup schedules validated weekly (nonprod) and daily (prod).
- AWS Backup vault copy jobs completing successfully.
- Route53 health checks + failover routing policies configured.
- Runbooks stored in Confluence + this repo, last reviewed quarterly.

### Recovery Steps (EKS + App)
1. **Declare Incident**: Engage incident commander, infra, app, DB, and security on-call.
2. **Assess Scope**: Review CloudWatch dashboards, Grafana, GuardDuty, and Incident Manager timeline.
3. **Failover Routing**:
   - If region impaired, flip Route53 failover records to the standby environment (pre-provisioned via Terraform).
   - If only the ALB is impacted, re-point the record to the healthy cluster’s ALB DNS name.
4. **EKS Cluster Recovery**:
   - Re-run Terraform in the target region/account (`base-infrastructure-bootstrap/terraform/envs/<env>` followed by `terraform/envs/<env>`).
   - AWS operates the EKS control plane—open a support case if the API endpoint is unavailable.
   - Reinstall Calico + namespaces (`k8s/namespaces/bootstrap.yaml`, `k8s/addons/calico`) and redeploy workloads via Helm (`k8s/helm/platform-chart` with the environment values file).
5. **Data Layer**:
   - Promote cross-region read replica to primary.
   - Update Secrets Manager rotation config with new writer endpoint.
   - Validate with application smoke tests.
6. **Application Verification**:
   - Execute synthetic tests (CloudWatch Synthetics).
   - Validate critical paths (login, checkout, payment, inventory update).
7. **Post-Incident**:
   - Initiate data reconciliation jobs.
   - Update status page + customer comms.
   - Conduct blameless postmortem within 48h, track action items in Jira.

### Testing Cadence
- GameDays every quarter alternating scenarios (region failover, RDS corruption, supply chain attack).
- Document findings in `docs/gameday-<date>.md`.

