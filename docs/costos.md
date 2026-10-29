# Estimado de Costos y Recortes

* Autor: **Camilo Rozo**

> **Borrador con valores de ejemplo.** Las cantidades y precios unitarios son supuestos por validar; los totales se recalculan en [costos.xlsx](costos.xlsx).

* **Calculadora de AWS:** _pendiente (enlace público de AWS Pricing Calculator)_
* **Archivo de apoyo:** [costos.xlsx](costos.xlsx), con tres hojas:
  * `Supuestos`: todas las entradas.
  * `Estimado`: líneas con fórmulas; sirve de especificación para cargar la calculadora.
  * `Recortes`: candidatos con su ahorro y su riesgo.

Los servicios que no están en la calculadora (OpenSearch Serverless NextGen, CloudWatch Omni) se calculan solo en el archivo, con los precios de su página.

## Costo mensual aproximado (región us-east-1, bajo demanda)

| Categoría | USD / mes (placeholder) |
|---|---|
| Cómputo (ECS Fargate en Graviton, servicio de firma en EC2) | 2,586 |
| Red (CloudFront, WAF, ALB, NAT, VPC Lattice, Client VPN) | 3,733 |
| Datos (RDS, OpenSearch Serverless) | 10,524 |
| Llaves y secretos (DynamoDB, KMS, Secrets Manager) | 142 |
| Observabilidad (CloudWatch Logs, S3, Athena) | 1,050 |
| Gobierno (Config, Security Hub, CloudTrail) | 260 |
| CI/CD (CodePipeline, CodeBuild, ECR) | 246 |
| DR en pilot light (réplicas de RDS, transferencia) | 4,966 |
| Cuentas no productivas (staging, dev, sandboxes) | 6,399 |
| **Total** | **~29,900 al mes (~359,000 al año)** |

**No incluye:** la licencia de New Relic u otra herramienta de APM, el plan de soporte de AWS, impuestos ni el costo del equipo. Tampoco descuentos por Savings Plans, que se evaluarían una vez estable el uso.

## Línea base: arquitectura actual

Estimado independiente de la arquitectura actual en [costos-actual.xlsx](costos-actual.xlsx), con los mismos supuestos compartidos (tráfico, tareas, bases, logs) para que la comparación sea justa:

* ECS en Fargate x86, sin Spot ni rightsizing.
* No productivo dentro de la misma cuenta, encendido 24/7.
* Dominio de OpenSearch con nodos fijos.
* Logs sin retención.
* VPN de terceros.
* Sin DR, sin gobierno y sin pipelines.

| Categoría | Actual (USD / mes) | Objetivo (USD / mes) | Diferencia |
|---|---|---|---|
| Cómputo | 3,604 | 2,586 | −1,018 |
| Red | 1,491 | 3,733 | +2,242 |
| Datos | 10,998 | 10,524 | −474 |
| Llaves y secretos | 130 | 142 | +12 |
| Observabilidad | 1,290 | 1,050 | −240 |
| Gobierno | 0 | 260 | +260 |
| CI/CD | 0 | 246 | +246 |
| DR | 0 | 4,966 | +4,966 |
| No productivo | 6,571 | 6,399 | −172 |
| **Total** | **~24,100** | **~29,900** | **+5,800 (+24 %)** |

**Lo que agrega el objetivo:**

* El DR en pilot light, que hoy no existe y es la mayor parte de la diferencia.
* VPC Lattice, CloudFront, AWS Client VPN, el gobierno (Config, Security Hub) y los pipelines.

**Lo que ahorra:**

* Graviton, Fargate Spot y el rightsizing en cómputo.
* Consolidar ALBs.
* La retención de logs con archivo en S3.
* OpenSearch Serverless en lugar de un dominio con nodos fijos.

Sin DR, el objetivo costaría menos que hoy. Los dos estimados usan valores de ejemplo por validar.

## Dos recortes concretos y el riesgo que agregan

Por elegir entre los candidatos de la hoja `Recortes`, todos derivados de las [decisiones](decisiones_short.md):

| Candidato | Ahorro aprox. (USD / mes) | Riesgo que agrega |
|---|---|---|
| DR solo con copias de AWS Backup entre regiones, sin réplicas vivas ([ADR-031](decisiones_full.md#adr-031-dr-pilot-light-en-una-segunda-región-sin-drs)) | 4,221 | El RPO pasa de minutos a horas y el RTO crece por la restauración de bases. |
| RDS no críticas en Single-AZ ([ADR-014](decisiones_full.md#adr-014-modernización-de-rds-según-motor-y-propósito)) | 2,453 | Una falla de zona deja esas bases caídas hasta restaurar. |
| Apagar staging fuera de horario ([ADR-003](decisiones_full.md#adr-003-estructura-de-ous-y-cuentas)) | 2,360 | Pruebas fuera de horario y tiempo de encendido. |
| Reemplazar VPC Lattice por ECS Service Connect ([ADR-017](decisiones_full.md#adr-017-vpc-lattice-en-lugar-de-transit-gateway)) | 1,535 | Se pierde la autorización de IAM entre servicios; la segmentación PCI queda solo en security groups. |
| Más servicios en Fargate Spot, de 20 % a 50 % ([ADR-013](decisiones_full.md#adr-013-modernización-del-cómputo-en-ecs)) | 646 | Interrupciones de tareas con dos minutos de aviso. |
