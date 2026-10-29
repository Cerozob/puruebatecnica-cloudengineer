# Prueba técnica · Platform / Cloud Engineer

* Autor: **Camilo Rozo**

Propuesta para llevar a Kova, una fintech de pagos con stablecoins que hoy opera en una sola cuenta de AWS sin infraestructura como código, a una plataforma multicuenta, gobernada y modernizada en 12 meses, sin downtime perceptible.

> Estado: borrador. Los diagramas se exportan desde Eraser a `docs/diagramas/`; el estimado de costos tiene valores de ejemplo por validar.

## Entregables

| Entregable | Documento |
|---|---|
| Arquitectura actual, suposiciones y arquitectura objetivo | [docs/arquitectura.md](docs/arquitectura.md) |
| Plan de migración y modernización | [docs/plan-migracion.md](docs/plan-migracion.md) |
| Decisiones y suposiciones (resumen) | [docs/decisiones_short.md](docs/decisiones_short.md) |
| Decisiones (detalle) | [docs/decisiones_full.md](docs/decisiones_full.md) |
| Estimado de costos y recortes (borrador) | [docs/costos.md](docs/costos.md), [docs/costos.xlsx](docs/costos.xlsx) |
| Línea base de costos de la arquitectura actual (borrador) | [docs/costos-actual.xlsx](docs/costos-actual.xlsx) |
| Controles de seguridad de los primeros 90 días | [docs/seguridad-90-dias.md](docs/seguridad-90-dias.md) |
| Esqueleto de IaC en Terraform | [infra/](infra/README.md) |
| Uso de IA generativa | [docs/uso-de-ia-generativa.md](docs/uso-de-ia-generativa.md) |

## Resumen de la propuesta

* **Producción no se mueve.** La cuenta actual se queda como producción y se une a una organización nueva; lo que sale es todo lo demás. Es la base del cero downtime.
* **Organización:** cuenta de administración nueva con Control Tower, AFT e IAM Identity Center; cuentas de seguridad, Deployments, staging, dev y sandboxes temporales.
* **Todo en Terraform:** se importa lo sensible y se reconstruye lo efímero; las personas solo leen en producción.
* **Plataforma:** ECS en Fargate y Graviton, VPC Lattice entre servicios, OpenTelemetry en todo, llaves de wallets en Nitro Enclaves con KMS y DynamoDB, y DR en pilot light en una segunda región.
* **Sin tocar** DNS, IPs, la integración con Stellar ni Temporal.
