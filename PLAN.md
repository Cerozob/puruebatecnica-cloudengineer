# Working plan — Platform / Cloud Engineer technical trial (Kova)

Internal working doc (English). Final deliverables are in Spanish. No IaC code until the last phase.

## 1. What the trial asks for and how we map it

| # (trial) | Trial deliverable | Weight | Our deliverable | File (draft → final) |
|---|---|---|---|---|
| 4 | Migration plan: phases, what first, what not to touch, no perceptible downtime | **Highest** | Multi-page wave plan following AWS Prescriptive Guidance (large-migration playbook) + MAP / AWS support mention | `docs/plan-migracion.md` |
| 1 | Target architecture (12 months): org & OUs, network, compute, data, secrets & keys (incl. wallet signing keys), CI/CD, observability | 2nd | Solution overview, AWS Solutions Library "How it works" style: page 1 = as-is + assumptions, page 2 = target + numbered narrative. SVGs exported from Eraser | `docs/arquitectura.md` + `docs/diagramas/*.svg` |
| 2 | ADR (1 page): one hard decision | 3rd | `decisiones_short.md`-style table of all ADRs + full ADRs for every decision; the "one" for the trial is flagged | `docs/decisiones_short.md`, `docs/decisiones_full.md` |
| 3 | Cost estimate + 2 concrete cuts with added risk | 4th | AWS Pricing Calculator public link + one-page tradeoff disclosure (cuts come from ADRs) + xlsx only if something is not in the calculator | `docs/costos.md` |
| 5 | Security controls, first 90 days (access, secrets, network, audit, IR) | Plus | One-pager | `docs/seguridad-90-dias.md` |
| 6 | IaC skeleton (Terraform/Pulumi), module structure + one example | Plus | Terraform (aws + awscc where needed), README is the deliverable entry point | `infra/`, `README.md` |
| — | AI usage paragraph | Rule | Same structure as ssraidev `uso-de-ia-generativa.md`, rewritten | `docs/uso-de-ia-generativa.md` |
| — | All assumptions in one place | Rule | Covered by the ADR set (ADRs = decisions based on assumptions). **Proposal:** still add a short "Suposiciones" index table at the top of `decisiones_short.md` (or as the first ADR group) so the evaluator finds them "in one place" literally | inside `decisiones_short.md` |
| — | Single PDF / link | Rule | `docs/entrega/build.py` reused from ssraidev, minus video/eval sections | `docs/entrega/entrega.pdf` |

Live session (75 min) changes restrictions on us — so every ADR should state *what would change the decision* (that is our prep for the defense block).

## 2. Phases (in order)

1. **Assumptions & questions** — fix the numbers the trial leaves open (section 4). Output: assumption list (EN draft).
2. **Target architecture design** — decide the open design points (section 5), one by one, with options + one recommendation each. You decide; I research/challenge.
3. **Diagrams (Eraser, diagram-as-code only)** — `As-is` and `Target` in the *Meru diagrams* file. I write the code; you add the step numbers.
4. **ADRs** — full + short, written from the decisions in phase 2.
5. **Migration plan** — waves, built on the target + ADRs (it is the highest-weight item, so it gets the most review time).
6. **Cost** — line-item spec → calculator link → 2 cuts.
7. **Security 90 days** — one-pager.
8. **Terraform skeleton** — module layout + one worked example (only phase with code).
9. **Spanish final versions + AI usage doc + build PDF**.

## 3. Repo layout (proposed)

```
README.md                      # entry point: links to every deliverable, how to read the repo
PLAN.md                        # this file (remove or keep out of the PDF at the end)
docs/
  arquitectura.md              # 2 pages: as-is + assumptions / target + numbered narrative
  diagramas/as-is.svg, objetivo.svg
  decisiones_short.md, decisiones_full.md
  plan-migracion.md
  costos.md                    # calculator link + 2 cuts
  seguridad-90-dias.md
  uso-de-ia-generativa.md
  entrega/build.py, entrega.html, entrega.pdf
infra/                         # Terraform skeleton (last)
```

## 4. Assumptions to fix (my starting proposals — to confirm/override)

| Topic | Proposal | Why |
|---|---|---|
| Region | Primary `us-east-1`; DR region TBD (`us-west-2`?) | LatAm-heavy users → `sa-east-1` is pricier; compliance/data residency unknown |
| Traffic | ~10k req/min avg (~170 rps), peak 3–5x | Given in the brief |
| Transactions | ~300k money movements/day (~3.5 tps avg) | "hundreds of thousands/day" |
| Services | ~40 ECS services, ~10+ clusters today | "several dozen", "many clusters" |
| Databases | 20–25 RDS PostgreSQL instances, mixed sizes, mostly Multi-AZ? (unknown) | Brief says >20 RDS |
| Temporal | Self-hosted on ECS (with its own RDS/OpenSearch for visibility) vs Temporal Cloud — **unknown, big impact** | Decides migration risk & cost |
| RTO / RPO | Ledger/payments: RTO ≤ 1 h, RPO ≤ 5 min (≈0 for ledger with Multi-AZ); non-critical: RTO 4 h | Typical fintech, small team |
| Team | ~8–15 engineers, 1–2 platform people | "small team" |
| Budget | Current spend unknown; assume target must not exceed current +15% after cleanup | Gives cost cuts a reason |
| Compliance | PCI-DSS likely out of scope (no card data); SOC 2 + local regulators (custody of keys) in scope | Stablecoin payments, no cards |
| Wallet signing keys | Today: unknown (assume in app config/Secrets Manager — the worst realistic case) | Drives a key ADR |
| Observability | New Relic today, Datadog under evaluation | Given |
| Deploy today | Manual / ad-hoc scripts, no IaC | Given |

## 5. Design decisions to make (candidate ADR list)

Each one: options → my recommendation → your call. Marked ★ = candidate for "the one hard ADR".

**Organization & accounts**
1. Landing zone: Control Tower + AFT vs Control Tower + plain Terraform vs Organizations only.
2. OU structure (Security, Infrastructure/Shared, Workloads Prod/NonProd, Sandbox, Suspended, + a dedicated **Custody/Signing** OU or account?).
3. Account granularity: per-env vs per-env-per-domain (payments, ledger, platform). ★ (blast radius vs ops cost for a small team)
4. What happens to the current single account: becomes legacy prod and is drained, vs becomes the new prod account in place. ★ (strongly ties to the migration plan)

**Network**
5. Transit Gateway vs VPC peering vs VPC Lattice / shared VPC (RAM).
6. Egress: centralized egress + Network Firewall (fixed egress IPs are usually required by local payment providers) vs per-VPC NAT.
7. Ingress: CloudFront + WAF + ALB vs ALB + WAF only; API Gateway in front or not.
8. Team access: replace VPN with IAM Identity Center + SSM Session Manager / Verified Access, or keep VPN.

**Compute**
9. Stay on ECS (consolidate clusters, Fargate vs EC2 capacity providers) vs move to EKS. ★
10. Deployment strategy: ECS blue/green (native) / CodeDeploy, canary.

**Data**
11. RDS → Aurora PostgreSQL or stay RDS; consolidate 20+ DBs or not.
12. Migration mechanism for DBs across accounts: snapshot share + restore, DMS CDC, logical replication, or AWS-native blue/green (same-account only). ★
13. OpenSearch: keep managed domains vs Serverless; role (search vs logs).
14. Temporal: self-host on ECS/EKS vs Temporal Cloud. ★

**Secrets & keys**
15. Wallet signing keys: KMS asymmetric (ECC_SECG_P256K1 / Ed25519 for Stellar — verify support) vs CloudHSM vs MPC custody provider (Fireblocks-type) vs Nitro Enclaves. ★★ (likely the strongest ADR candidate)
16. Secrets: Secrets Manager with rotation vs SSM Parameter Store; per-account KMS CMKs.

**CI/CD & IaC**
17. Terraform layout: monorepo with modules + live per account vs separate repos; state in S3 per account with native locking; Terraform Cloud/Atlantis vs GitHub Actions + OIDC.
18. Importing existing hand-made infra: `import` blocks / Terraformer vs rebuild. ★
19. App CI/CD: GitHub Actions + OIDC → ECR → ECS deploy.

**Observability**
20. New Relic vs Datadog vs CloudWatch/OTel-native, and the migration path (OTel collector as the decoupling layer). ★
21. Centralized logs/CloudTrail in Log Archive account; Security Hub/GuardDuty org-wide.

**Resilience**
22. Multi-AZ only vs warm-standby multi-region for the payments path.

## 6. Tooling status (checked this session)

- **Eraser**: connected; *Meru diagrams* file exists (`Ij84o5Dz4IH3ScJQkZkG`), currently empty. Will use diagram-as-code only (no AI generation tools).
- **`aws-pricing-calculator-mcp-server`**: **not present** in this session (needs the restart you mentioned). What *is* connected is the AWS Price List MCP (`awspricing`): it gives unit prices but **cannot create a shareable calculator link**. Fallback: I produce the full line-item spec (service, config, quantity, region) and either the calculator MCP builds it or you enter it in calculator.aws.
- **AWS docs MCP**: connected (for Prescriptive Guidance, MAP, service limits/feature checks).
- **ssraidev references**: `decisiones_short.md`, `decisiones_full.md`, `uso-de-ia-generativa.md`, `entrega/build.py` read; build.py is reusable with section list changes.

## 7. Open points for you

- **Confidentiality:** the brief says "do not share or publish", and this repo is **public**. I will not commit the brief PDF nor quote it verbatim. Do you want the repo private until submission?
- The "one ADR" for the trial: pick after phase 2 (my early bet: wallet signing keys, or single account → multi-account cutover).
- Time budget: trial says 3–4 h for mandatory items; we are clearly going beyond — keep the 4 > 1 > 2 > 3 priority in how much polish each gets.
