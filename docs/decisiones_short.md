# Decisiones Técnicas (Resumen)

* Autor: **Camilo Rozo**

Resumen de las suposiciones y de las decisiones de arquitectura. El detalle de cada decisión (contexto, opciones, consecuencias y qué la cambiaría) está en [decisiones_full.md](decisiones_full.md). Los números `1?`–`12?` corresponden al diagrama de la arquitectura actual en [arquitectura.md](arquitectura.md).

## Suposiciones

| ID | Tema | Suposición | Diagrama |
|---|---|---|---|
| S-01 | Región | `us-east-1` como región principal; la región de DR no se define. | — |
| S-02 | Tráfico | ~10 mil solicitudes por minuto, picos de 3 a 5 veces; el autoescalado probablemente ya está configurado. | `4?` |
| S-03 | Cómputo | Hasta 100 servicios en ECS; número de clusters, tipo de lanzamiento y balanceadores desconocidos. | `3?` `4?` |
| S-04 | Bases de datos | Hasta 30 instancias de RDS con motores, tamaños, configuraciones y propósitos diversos. | `7?` |
| S-05 | OpenSearch | Configuración y propósito (búsqueda o logs) desconocidos. | `6?` |
| S-06 | Temporal | Self-hosted en ECS en la misma cuenta; su persistencia es una de las bases de RDS. | `5?` `8?` |
| S-07 | RTO / RPO | RTO de 1 hora para todo (por las dependencias entre sistemas) y RPO de 5 minutos; se espera una estrategia de DR. | — |
| S-08 | Equipo | 10 ingenieros, con dos turnos de guardia 24/7 en varias zonas horarias. | `1?` |
| S-09 | Cumplimiento | Aplica PCI DSS (Kova emite tarjetas) a través de un issuer-processor; la Ley 1581 de Habeas Data ya se cumple. | — |
| S-10 | Secretos y llaves | Secretos en Secrets Manager / SSM; llaves de wallets en KMS o cifradas en un almacén existente, ubicación exacta desconocida. | `9?` `10?` `12?` |
| S-11 | Red | DNS, IPs públicas e IPs de salida en listas blancas de proveedores no cambian. | `11?` |
| S-12 | VPN | Producto y proveedor desconocidos; da acceso de red a las VPCs. | `2?` |
| S-13 | Observabilidad | APM actual: New Relic; se evalúan alternativas sin preferencia previa. | — |
| S-14 | Blockchain | Red Stellar (curva Ed25519); sin información de nodos ni de Horizon. | — |
| S-15 | Código | El código vive en GitHub (o en su host actual). | — |
| S-16 | Facturación | No hay acuerdos atados a la cuenta actual como pagadora que impidan unirla a una organización (se valida antes). | — |
| S-17 | Wallets | El número de wallets es alto (miles o más), por lo que una llave de KMS por wallet no es viable en costo. | `10?` |

## Decisiones

| ID | Nombre | Descripción | Razón |
|---|---|---|---|
| [ADR-001](decisiones_full.md#adr-001-organización-de-aws-con-una-cuenta-de-administración-nueva) | Organización | Cuenta de administración nueva; la cuenta actual se invita como miembro | Práctica de AWS: sin cargas en la cuenta de administración, a la que no le aplican SCPs. |
| [ADR-002](decisiones_full.md#adr-002-la-cuenta-actual-se-mantiene-como-cuenta-de-producción) | Cuenta de producción | La cuenta actual sigue siendo producción | Mover producción es el mayor riesgo de downtime; se conservan IDs, IPs, DNS y llaves. |
| [ADR-003](decisiones_full.md#adr-003-estructura-de-ous-y-cuentas) | OUs y cuentas | Security, Infrastructure, Workloads (Prod transitoria y NonProd) y Sandbox; cuentas por entorno | Simple de operar para un equipo de 10. |
| [ADR-004](decisiones_full.md#adr-004-aft-sobre-control-tower-para-crear-cuentas) | Creación de cuentas | Control Tower con AFT | El requisito es Terraform; LZA es CDK. |
| [ADR-005](decisiones_full.md#adr-005-innovation-sandbox-on-aws-para-los-sandboxes) | Sandboxes | Innovation Sandbox on AWS; se acepta el drift de Control Tower como señal | Presupuesto y limpieza automática por cuenta. |
| [ADR-006](decisiones_full.md#adr-006-acceso-humano-de-solo-lectura-en-producción) | Acceso a producción | Personas solo lectura; cambios solo por roles de IaC; *break-glass* alertado | La IaC como única vía de cambio; mínimo privilegio. |
| [ADR-007](decisiones_full.md#adr-007-scps-en-todas-las-cuentas-excepto-producción) | SCPs | Restrictivas en todas las cuentas menos producción | No romper flujos de producción no documentados. |
| [ADR-008](decisiones_full.md#adr-008-todo-a-iac-importar-lo-sensible-reconstruir-lo-efímero) | Adopción de IaC | Importar lo sensible y expuesto; reconstruir lo efímero | Adoptar producción sin tocarla. |
| [ADR-009](decisiones_full.md#adr-009-terraform-con-los-proveedores-aws-y-awscc) | Herramienta de IaC | Terraform con `aws` y `awscc` | Requisito; `awscc` cubre servicios nuevos. |
| [ADR-010](decisiones_full.md#adr-010-estructura-del-repositorio-y-estado-de-terraform) | Layout de Terraform | Patrones `aws-ia`/`aws-samples`; S3 con bloqueo nativo; un estado por cuenta y componente | Estándar de la industria; estados pequeños. |
| [ADR-011](decisiones_full.md#adr-011-la-migración-es-una-limpieza-de-la-cuenta-de-producción) | Estrategia de migración | Retain para producción, sacar el no productivo, retire de huérfanos | Cero downtime: producción no se mueve. |
| [ADR-012](decisiones_full.md#adr-012-rehost-o-rebuild-del-no-productivo-según-la-carga) | No productivo | Rehost o rebuild según la carga (abierto) | No bloquear la limpieza en casos difíciles. |
| [ADR-013](decisiones_full.md#adr-013-modernización-del-cómputo-en-ecs) | Cómputo | Seguir en ECS; Fargate, Graviton, rightsizing, Spot | El equipo conoce ECS; menos operación y costo. |
| [ADR-014](decisiones_full.md#adr-014-modernización-de-rds-según-motor-y-propósito) | Bases de datos | Rightsizing o Aurora según motor y propósito, con Blue/Green | Ahorro sin downtime perceptible. |
| [ADR-015](decisiones_full.md#adr-015-opensearch-serverless-nextgen) | OpenSearch | OpenSearch Serverless NextGen | Escala a cero y cobra por uso. |
| [ADR-016](decisiones_full.md#adr-016-temporal-se-mantiene-self-hosted-durante-12-meses) | Orquestación | Temporal self-hosted en ECS, sin cambios por 12 meses | Experiencia del equipo; otra migración no aporta. |
| [ADR-017](decisiones_full.md#adr-017-vpc-lattice-en-lugar-de-transit-gateway) | Conectividad entre servicios | VPC Lattice con autenticación de IAM | Confianza cero, sin problemas de CIDR; costo aceptado. |
| [ADR-018](decisiones_full.md#adr-018-ingreso-con-cloudfront-waf-y-alb-sin-cambios) | Ingreso | CloudFront, WAF y ALB sin cambios | Cero cambio visible para los clientes. |
| [ADR-019](decisiones_full.md#adr-019-aws-client-vpn-e-iam-identity-center-para-el-equipo) | Acceso del equipo | AWS Client VPN con IAM Identity Center | Una sola identidad, auditada. |
| [ADR-020](decisiones_full.md#adr-020-dns-ips-y-direcciones-de-salida-sin-cambios) | Direcciones | DNS, IPs y NAT sin cambios | Listas blancas de proveedores intactas. |
| [ADR-021](decisiones_full.md#adr-021-llaves-de-firma-de-wallets-con-nitro-enclaves-kms-y-dynamodb) | Llaves de wallets | Cifrado de sobre: DynamoDB + KMS con atestación + Nitro Enclaves en EC2 | Costo independiente del número de wallets; la llave en claro solo existe en el enclave. CloudHSM descartado por costo. |
| [ADR-022](decisiones_full.md#adr-022-las-llaves-permanecen-en-la-cuenta-de-producción) | Ubicación de las llaves | Se quedan en producción | Las llaves de KMS no se mueven entre cuentas. |
| [ADR-023](decisiones_full.md#adr-023-origen-de-las-llaves-conservar-importar-o-generar-fuera-e-importar) | Origen de las llaves | Conservar, importar o generar fuera e importar | Portabilidad, sin atarse a un proveedor. |
| [ADR-024](decisiones_full.md#adr-024-secretos-de-configuración-en-secrets-manager-y-ssm) | Secretos | Secrets Manager y SSM `SecureString` | Práctica recomendada, ya en uso. |
| [ADR-025](decisiones_full.md#adr-025-codepipeline-y-codebuild-en-una-cuenta-de-deployments) | CI/CD | CodePipeline y CodeBuild en una cuenta de Deployments; GitHub vía CodeConnections | Todo en AWS; sin credenciales permanentes. |
| [ADR-026](decisiones_full.md#adr-026-despliegues-bluegreen-nativos-de-ecs) | Estrategia de despliegue | Blue/green nativo de ECS, sin CodeDeploy | Menos piezas. |
| [ADR-027](decisiones_full.md#adr-027-opentelemetry-como-capa-de-desacople-de-observabilidad) | Observabilidad | OpenTelemetry en todo; New Relic se mantiene; se evalúan alternativas | Cambiar de herramienta sin re-instrumentar. |
| [ADR-028](decisiones_full.md#adr-028-retención-de-logs-y-archivo-en-s3-con-athena) | Logs | Retención en todo; archivo en S3 consultado con Athena | Costo predecible. |
| [ADR-029](decisiones_full.md#adr-029-finops-etiquetado-obligatorio-presupuestos-y-anomalías) | FinOps | Etiquetas obligatorias, Budgets, Cost Anomaly Detection, topes en dev y sandboxes | Saber qué cuesta cada cosa. |
| [ADR-030](decisiones_full.md#adr-030-cloudtrail-organizacional-aws-config-y-security-hub) | Auditoría | CloudTrail organizacional, Config (paquete PCI) y Security Hub | Trazabilidad y hallazgos centralizados. |
| [ADR-031](decisiones_full.md#adr-031-dr-pilot-light-en-una-segunda-región-sin-drs) | DR | Pilot light multirregión; DRS descartado | Cumple RTO/RPO al menor costo; DRS no cubre ECS ni RDS. |
| [ADR-032](decisiones_full.md#adr-032-no-tocar-la-infraestructura-blockchain) | Blockchain | No se toca la integración con Stellar | Sin contexto suficiente; pieza crítica. |
| [ADR-033](decisiones_full.md#adr-033-reducción-del-alcance-pci-con-issuer-processor-y-segmentación) | PCI | Issuer-processor + segmentación con Lattice dentro de producción | Alcance mínimo sin mover nada. |
