# Plan de Migración y Modernización

* Autor: **Camilo Rozo**

Cómo llevar a Kova de su estado actual a la [arquitectura objetivo](arquitectura.md) en 12 meses, sin downtime perceptible en un sistema financiero 24/7. El plan sigue las fases de la guía de AWS para migraciones grandes (evaluar, movilizar, migrar y modernizar) y las estrategias 7R. Las decisiones citadas están en [decisiones_full.md](decisiones_full.md).

## La idea central

**Producción no se mueve.** La cuenta actual se queda como cuenta de producción ([ADR-002](decisiones_full.md#adr-002-la-cuenta-actual-se-mantiene-como-cuenta-de-producción)); lo que sale es todo lo demás. Por eso la "migración" es en realidad una limpieza de la cuenta de producción más la construcción de la plataforma alrededor de ella:

| Estrategia (7R) | Qué cubre |
|---|---|
| Retain | Producción: se queda en su cuenta y se adopta en IaC y en la organización. |
| Rehost / Relocate o rebuild | No productivo: sale a staging y dev, según la carga ([ADR-012](decisiones_full.md#adr-012-rehost-o-rebuild-del-no-productivo-según-la-carga)). |
| Retire | Recursos huérfanos encontrados en el inventario. |
| Replatform / Refactor | Modernización posterior: Fargate y Graviton, Aurora, OpenSearch Serverless NextGen, VPC Lattice, servicio de firma. |

## Principios de cero downtime

1. **Nada de producción se mueve** de cuenta, región, IP ni DNS.
2. **Todo cambio es aditivo y en paralelo**: lo nuevo se construye al lado de lo viejo y el tráfico se pasa de a poco.
3. **Todo cambio es reversible** y tiene un plan de vuelta atrás probado antes de empezar.
4. **Las herramientas de migración no tocan producción.** Se usan solo con el no productivo.
5. **Un import de Terraform solo se aplica si el plan no muestra cambios.**
6. **Despliegues blue/green** para servicios y bases de datos.
7. **Cortes en horas de menor tráfico** y congelamiento de cambios alrededor de eventos de alto volumen.

## Qué hacemos primero y por qué

1. **Inventario y etiquetas.** Sin saber qué es producción y qué no, cualquier movimiento es una apuesta. Además resuelve las suposiciones `1?`–`12?`.
2. **La organización y la auditoría.** No cambian nada en producción y nos dan visibilidad (CloudTrail, Config) antes de tocar cualquier cosa.
3. **Adoptar producción en Terraform.** Una vez que producción está en código, cada cambio posterior es revisable y reversible.
4. **Sacar el no productivo.** Reduce el riesgo de que un cambio de pruebas afecte a clientes.
5. **Modernizar.** Solo cuando lo anterior está estable.

## Qué no tocamos y por qué

| Componente | Por qué no se toca |
|---|---|
| La cuenta de producción (no se cambia de cuenta) | Moverla es el mayor riesgo de downtime ([ADR-002](decisiones_full.md#adr-002-la-cuenta-actual-se-mantiene-como-cuenta-de-producción)). |
| DNS, IPs públicas y de salida | Los proveedores de pagos tienen en lista blanca las IPs actuales ([ADR-020](decisiones_full.md#adr-020-dns-ips-y-direcciones-de-salida-sin-cambios)). |
| Integración con la red Stellar | Pieza crítica sin contexto suficiente ([ADR-032](decisiones_full.md#adr-032-no-tocar-la-infraestructura-blockchain)). |
| Temporal | El equipo lo conoce; migrarlo no aporta en 12 meses ([ADR-016](decisiones_full.md#adr-016-temporal-se-mantiene-self-hosted-durante-12-meses)). |
| Llaves de KMS existentes | No se pueden mover entre cuentas ([ADR-022](decisiones_full.md#adr-022-las-llaves-permanecen-en-la-cuenta-de-producción)). |
| CloudFront, WAF y ALB | Ingreso de clientes; solo se importan a IaC ([ADR-018](decisiones_full.md#adr-018-ingreso-con-cloudfront-waf-y-alb-sin-cambios)). |
| New Relic (durante la migración) | Es la visibilidad que necesitamos mientras cambiamos todo lo demás. |

## Fases

### Fase 0. Evaluar (semanas 1 a 4)

* Activar AWS Config y Resource Explorer en la cuenta actual y sacar el inventario completo.
* Mapear dependencias con VPC Flow Logs y los mapas de servicios de New Relic.
* Clasificar cada recurso como producción, no productivo o huérfano, y etiquetar (`environment`, `service`, `owner`, `data-classification`).
* Responder las suposiciones: motores de RDS, persistencia de Temporal, dónde están las llaves de wallets, cómo es la VPN, qué balanceadores existen.
* Línea base de costos por servicio con las etiquetas nuevas y Cost Explorer.
* Abrir la conversación con el equipo de cuenta de AWS (ver [Apoyo de AWS](#apoyo-de-aws)).

**Criterio de salida:** el 100 % de los recursos tiene `environment` y dueño; lista de huérfanos aprobada.

### Fase 1. Movilizar: la fundación (semanas 3 a 10)

* Crear la cuenta de administración, la organización, Control Tower (Log Archive y Audit), IAM Identity Center y AFT ([ADR-001](decisiones_full.md#adr-001-organización-de-aws-con-una-cuenta-de-administración-nueva), [ADR-004](decisiones_full.md#adr-004-aft-sobre-control-tower-para-crear-cuentas)).
* Revisar los acuerdos de facturación y luego invitar a la cuenta actual a la OU transitoria de producción, sin SCPs restrictivas. **Impacto en producción: ninguno.**
* CloudTrail organizacional, Config y Security Hub ([ADR-030](decisiones_full.md#adr-030-cloudtrail-organizacional-aws-config-y-security-hub)).
* Crear con AFT las cuentas Deployments, staging, dev y el pool de Innovation Sandbox, con SCPs restrictivas.
* Repositorio de Terraform, backend S3 y pipelines base ([ADR-010](decisiones_full.md#adr-010-estructura-del-repositorio-y-estado-de-terraform), [ADR-025](decisiones_full.md#adr-025-codepipeline-y-codebuild-en-una-cuenta-de-deployments)).
* Permission sets de Identity Center: solo lectura para producción y rol *break-glass*. Los accesos actuales todavía no se quitan.

**Criterio de salida:** la cuenta de producción está en la organización, con CloudTrail centralizado y sin ningún incidente atribuible.

### Fase 2. Adoptar producción en IaC (meses 2 a 5)

Se importa por componentes, de menor a mayor riesgo, con la regla de plan sin cambios ([ADR-008](decisiones_full.md#adr-008-todo-a-iac-importar-lo-sensible-reconstruir-lo-efímero)):

1. Red: VPCs, subredes, security groups, NAT y Elastic IPs.
2. Ingreso: CloudFront, WAF, ALB, certificados y DNS.
3. Datos: RDS, OpenSearch, DynamoDB, KMS.
4. Cómputo: los servicios de ECS no se importan, se redefinen en Terraform y se redespliegan con blue/green, uno por uno.

En paralelo:

* Instrumentar con OpenTelemetry servicio por servicio, enviando a New Relic igual que hoy ([ADR-027](decisiones_full.md#adr-027-opentelemetry-como-capa-de-desacople-de-observabilidad)).
* Retención en todos los grupos de logs ([ADR-028](decisiones_full.md#adr-028-retención-de-logs-y-archivo-en-s3-con-athena)).
* Cuando el pipeline está probado para un equipo, se quitan sus permisos de escritura en producción ([ADR-006](decisiones_full.md#adr-006-acceso-humano-de-solo-lectura-en-producción)).

**Vuelta atrás:** un import no cambia el recurso; si algo sale mal se quita del estado con `terraform state rm`. Un redespliegue blue/green vuelve solo al servicio anterior.

**Criterio de salida:** toda la producción está en Terraform y ninguna persona tiene permisos de escritura en producción.

### Fase 3. Sacar el no productivo, por oleadas (meses 3 a 7)

| Oleada | Contenido | Estrategia |
|---|---|---|
| 1. Piloto | 2 o 3 servicios de dev sin estado | Rebuild con Terraform en la cuenta dev |
| 2. Dev | El resto de dev | Rebuild o rehost según la carga |
| 3. Staging | Staging y sus bases | Rehost con snapshots compartidos, o seeds nuevos |
| 4. Retiro | Recursos no productivos en la cuenta de producción | Detener, snapshot, cuarentena de 30 días y borrar |

* Los datos de producción nunca se copian a no productivo sin anonimizar (Habeas Data y PCI).
* Cada oleada valida que producción no dependía de lo que se movió (los flujos de VPC y CloudTrail de la fase 0 lo muestran).

**Vuelta atrás:** hasta el fin de la cuarentena, los recursos viejos siguen en la cuenta de producción, detenidos y recuperables.

### Fase 4. Plataforma objetivo alrededor de producción (meses 4 a 9)

Todo se construye en paralelo y se activa de a poco:

* **AWS Client VPN** en paralelo con la VPN actual; corte cuando todo el equipo migró ([ADR-019](decisiones_full.md#adr-019-aws-client-vpn-e-iam-identity-center-para-el-equipo)).
* **VPC Lattice**: se crean las service networks y se mueven las llamadas entre servicios una por una; la ruta vieja queda hasta que la nueva está validada ([ADR-017](decisiones_full.md#adr-017-vpc-lattice-en-lugar-de-transit-gateway)).
* **Segmentación PCI** de los servicios de tarjetas en su propia service network ([ADR-033](decisiones_full.md#adr-033-reducción-del-alcance-pci-con-issuer-processor-y-segmentación)).
* **Servicio de firma con Nitro Enclaves** ([ADR-021](decisiones_full.md#adr-021-llaves-de-firma-de-wallets-con-nitro-enclaves-kms-y-dynamodb)):
  1. Ceremonia de llaves: cifrar las llaves existentes con la llave de KMS nueva y cargarlas en DynamoDB.
  2. Modo sombra: el servicio nuevo firma en paralelo sin enviar; las firmas Ed25519 son deterministas, así que se comparan byte a byte con las actuales.
  3. Corte por grupos de wallets, con vuelta atrás inmediata al firmante actual.
* **DR pilot light**: réplicas de RDS entre regiones, tabla global, llave réplica de KMS y replicación de ECR; primer simulacro de conmutación ([ADR-031](decisiones_full.md#adr-031-dr-pilot-light-en-una-segunda-región-sin-drs)).
* **Evaluación de observabilidad**: el colector OpenTelemetry envía en paralelo a New Relic y a los candidatos.
* **FinOps**: presupuestos, anomalías y topes ([ADR-029](decisiones_full.md#adr-029-finops-etiquetado-obligatorio-presupuestos-y-anomalías)).

### Fase 5. Modernizar (meses 6 a 12)

* **ECS** ([ADR-013](decisiones_full.md#adr-013-modernización-del-cómputo-en-ecs)): Fargate y Graviton servicio por servicio con blue/green; rightsizing con las recomendaciones de AWS Compute Optimizer; Fargate Spot donde se tolere; consolidar clusters.
* **RDS** ([ADR-014](decisiones_full.md#adr-014-modernización-de-rds-según-motor-y-propósito)): RDS Blue/Green Deployments para cambios de versión y tamaño; migración a Aurora con réplica de lectura y promoción en horas de bajo tráfico.
* **OpenSearch** ([ADR-015](decisiones_full.md#adr-015-opensearch-serverless-nextgen)): doble escritura, carga histórica, cambio de lecturas por alias y el dominio viejo como vuelta atrás.
* **SCPs mínimas en producción** si el inventario muestra que son seguras ([ADR-007](decisiones_full.md#adr-007-scps-en-todas-las-cuentas-excepto-producción)).

## Cronograma

| Fase | M1 | M2 | M3 | M4 | M5 | M6 | M7 | M8 | M9 | M10 | M11 | M12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0. Evaluar | ■ | | | | | | | | | | | |
| 1. Fundación | ■ | ■ | ■ | | | | | | | | | |
| 2. Producción a IaC | | ■ | ■ | ■ | ■ | | | | | | | |
| 3. Sacar no productivo | | | ■ | ■ | ■ | ■ | ■ | | | | | |
| 4. Plataforma objetivo | | | | ■ | ■ | ■ | ■ | ■ | ■ | | | |
| 5. Modernizar | | | | | | ■ | ■ | ■ | ■ | ■ | ■ | ■ |

Con un equipo de 10 personas y guardias 24/7, se asume que dos personas dedican la mayor parte de su tiempo a este plan y el resto participa por servicio.

## Riesgos principales

| Riesgo | Mitigación |
|---|---|
| Un recurso "de pruebas" lo usa producción | Mapa de dependencias de la fase 0 y cuarentena de 30 días antes de borrar. |
| Un import cambia un recurso de producción | Regla de plan sin cambios; revisión obligatoria del plan en el pipeline. |
| Quitar permisos humanos deja al equipo sin acción en un incidente | Rol *break-glass* probado antes de quitar permisos; pipeline de despliegue rápido. |
| Una firma incorrecta del servicio nuevo | Modo sombra con comparación exacta y corte por grupos de wallets. |
| El DR no cumple el RTO | Simulacros periódicos del `terraform apply` en la región de DR. |
| El equipo se satura | Fases secuenciales, oleadas pequeñas y apoyo de AWS. |

## Apoyo de AWS

* **Migration Acceleration Program (MAP)** sigue las mismas tres fases (evaluar, movilizar, migrar y modernizar) y puede aportar financiamiento y acompañamiento. Está pensado para migraciones hacia AWS; como Kova ya está en AWS, su aplicabilidad hay que confirmarla con el equipo de cuenta, sobre todo para la parte de modernización.
* **AWS Enterprise Support**: arquitecto técnico de cuenta, revisión Well-Architected y AWS Countdown para acompañar los cortes críticos.
* **AWS Professional Services o socios de AWS** para acelerar la fundación (Control Tower y AFT) o la adopción de IaC.
* **AWS Transform** para evaluaciones y modernización de código en etapas posteriores.
