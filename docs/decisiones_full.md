# Documento de Decisiones de Arquitectura

* Autor: **Camilo Rozo**

Cada decisión sigue el formato ADR: contexto, opciones, decisión, consecuencias y qué cambiaría la decisión. Las suposiciones en las que se apoyan están en [decisiones_short.md](decisiones_short.md#suposiciones). Los números de paso (`O1`–`O8` y `1`–`14`) hacen referencia a los diagramas de [arquitectura.md](arquitectura.md).

## Tabla de Contenidos

**Organización y gobierno**

1. [ADR-001: Organización de AWS con una cuenta de administración nueva](#adr-001-organización-de-aws-con-una-cuenta-de-administración-nueva)
2. [ADR-002: La cuenta actual se mantiene como cuenta de producción](#adr-002-la-cuenta-actual-se-mantiene-como-cuenta-de-producción)
3. [ADR-003: Estructura de OUs y cuentas](#adr-003-estructura-de-ous-y-cuentas)
4. [ADR-004: AFT sobre Control Tower para crear cuentas](#adr-004-aft-sobre-control-tower-para-crear-cuentas)
5. [ADR-005: Innovation Sandbox on AWS para los sandboxes](#adr-005-innovation-sandbox-on-aws-para-los-sandboxes)
6. [ADR-006: Acceso humano de solo lectura en producción](#adr-006-acceso-humano-de-solo-lectura-en-producción)
7. [ADR-007: SCPs en todas las cuentas excepto producción](#adr-007-scps-en-todas-las-cuentas-excepto-producción)

**Infraestructura como código**

8. [ADR-008: Todo a IaC: importar lo sensible, reconstruir lo efímero](#adr-008-todo-a-iac-importar-lo-sensible-reconstruir-lo-efímero)
9. [ADR-009: Terraform con los proveedores aws y awscc](#adr-009-terraform-con-los-proveedores-aws-y-awscc)
10. [ADR-010: Estructura del repositorio y estado de Terraform](#adr-010-estructura-del-repositorio-y-estado-de-terraform)

**Migración y modernización**

11. [ADR-011: La migración es una limpieza de la cuenta de producción](#adr-011-la-migración-es-una-limpieza-de-la-cuenta-de-producción)
12. [ADR-012: Rehost o rebuild del no productivo según la carga](#adr-012-rehost-o-rebuild-del-no-productivo-según-la-carga)
13. [ADR-013: Modernización del cómputo en ECS](#adr-013-modernización-del-cómputo-en-ecs)
14. [ADR-014: Modernización de RDS según motor y propósito](#adr-014-modernización-de-rds-según-motor-y-propósito)
15. [ADR-015: OpenSearch Serverless NextGen](#adr-015-opensearch-serverless-nextgen)
16. [ADR-016: Temporal se mantiene self-hosted durante 12 meses](#adr-016-temporal-se-mantiene-self-hosted-durante-12-meses)

**Red y acceso**

17. [ADR-017: VPC Lattice en lugar de Transit Gateway](#adr-017-vpc-lattice-en-lugar-de-transit-gateway)
18. [ADR-018: Ingreso con CloudFront, WAF y ALB sin cambios](#adr-018-ingreso-con-cloudfront-waf-y-alb-sin-cambios)
19. [ADR-019: AWS Client VPN e IAM Identity Center para el equipo](#adr-019-aws-client-vpn-e-iam-identity-center-para-el-equipo)
20. [ADR-020: DNS, IPs y direcciones de salida sin cambios](#adr-020-dns-ips-y-direcciones-de-salida-sin-cambios)

**Llaves y secretos**

21. [ADR-021: Llaves de firma de wallets con Nitro Enclaves, KMS y DynamoDB](#adr-021-llaves-de-firma-de-wallets-con-nitro-enclaves-kms-y-dynamodb)
22. [ADR-022: Las llaves permanecen en la cuenta de producción](#adr-022-las-llaves-permanecen-en-la-cuenta-de-producción)
23. [ADR-023: Origen de las llaves: conservar, importar o generar fuera e importar](#adr-023-origen-de-las-llaves-conservar-importar-o-generar-fuera-e-importar)
24. [ADR-024: Secretos de configuración en Secrets Manager y SSM](#adr-024-secretos-de-configuración-en-secrets-manager-y-ssm)

**CI/CD**

25. [ADR-025: CodePipeline y CodeBuild en una cuenta de Deployments](#adr-025-codepipeline-y-codebuild-en-una-cuenta-de-deployments)
26. [ADR-026: Despliegues blue/green nativos de ECS](#adr-026-despliegues-bluegreen-nativos-de-ecs)

**Observabilidad, FinOps y seguridad**

27. [ADR-027: OpenTelemetry como capa de desacople de observabilidad](#adr-027-opentelemetry-como-capa-de-desacople-de-observabilidad)
28. [ADR-028: Retención de logs y archivo en S3 con Athena](#adr-028-retención-de-logs-y-archivo-en-s3-con-athena)
29. [ADR-029: FinOps: etiquetado obligatorio, presupuestos y anomalías](#adr-029-finops-etiquetado-obligatorio-presupuestos-y-anomalías)
30. [ADR-030: CloudTrail organizacional, AWS Config y Security Hub](#adr-030-cloudtrail-organizacional-aws-config-y-security-hub)

**Resiliencia, blockchain y cumplimiento**

31. [ADR-031: DR pilot light en una segunda región, sin DRS](#adr-031-dr-pilot-light-en-una-segunda-región-sin-drs)
32. [ADR-032: No tocar la infraestructura blockchain](#adr-032-no-tocar-la-infraestructura-blockchain)
33. [ADR-033: Reducción del alcance PCI con issuer-processor y segmentación](#adr-033-reducción-del-alcance-pci-con-issuer-processor-y-segmentación)

---

## ADR-001: Organización de AWS con una cuenta de administración nueva

### Contexto

Hoy hay una sola cuenta donde conviven producción y no productivo. Se necesita separar entornos, gobernar con políticas y consolidar la facturación. La cuenta que crea la organización (cuenta de administración) tiene privilegios especiales y las SCPs no le aplican.

### Opciones consideradas

* Crear la organización desde la cuenta actual de producción.
* Crear una cuenta nueva solo para administrar la organización e invitar a la cuenta actual.
* Seguir con una sola cuenta y separar entornos con etiquetas y roles.

### Decisión

Se crea una cuenta de administración nueva, sin cargas de trabajo, con AWS Organizations, Control Tower, IAM Identity Center y la facturación consolidada (paso `O1`). La cuenta actual se invita como miembro.

### Consecuencias

#### Positivas

* Sigue la práctica recomendada por AWS de no desplegar cargas en la cuenta de administración.
* Un compromiso de producción no compromete la organización completa.
* Unirse a una organización no cambia el ID de la cuenta, y las RIs y Savings Plans se quedan con ella.

#### Negativas

* La cuenta nueva pasa a ser la pagadora: hay que revisar antes de invitar a producción los acuerdos atados al pagador (EDP o precios privados, ofertas privadas de Marketplace, plan de soporte).
* Una cuenta más que administrar.

### Qué cambiaría la decisión

* Que exista un acuerdo comercial atado a la cuenta actual como pagadora que no se pueda transferir.

---

## ADR-002: La cuenta actual se mantiene como cuenta de producción

### Contexto

Crear una cuenta de producción nueva implicaría mover más de 100 servicios, hasta 30 bases de datos, llaves de KMS (que no se pueden mover entre cuentas), IPs registradas en proveedores y DNS, en un sistema financiero 24/7.

### Opciones consideradas

* Nueva cuenta de producción y migrar todo.
* Mantener la cuenta actual como producción y sacar todo lo demás.

### Decisión

La cuenta actual se queda como producción (paso `O4`). Lo que sale es todo lo que no es producción (ver [ADR-011](#adr-011-la-migración-es-una-limpieza-de-la-cuenta-de-producción)).

### Consecuencias

#### Positivas

* Producción no se mueve: es el principal argumento de cero downtime.
* Se conservan IDs, IPs, DNS, llaves de KMS, cuotas y descuentos.

#### Negativas

* La cuenta arrastra deuda histórica (recursos huérfanos, permisos amplios) que hay que limpiar en sitio.
* No se obtiene una cuenta "limpia" de producción desde el día uno.

### Qué cambiaría la decisión

* Que la cuenta actual estuviera comprometida o que la deuda fuera tan grande que limpiar en sitio fuera más riesgoso que mover.

---

## ADR-003: Estructura de OUs y cuentas

### Contexto

Se necesita una estructura simple que un equipo de 10 ingenieros pueda operar, alineada con las guías de AWS para entornos multicuenta.

### Opciones consideradas

* Cuentas por entorno (prod, staging, dev).
* Cuentas por entorno y por dominio (pagos, wallets, tarjetas).

### Decisión

Cuentas por entorno, con estas OUs (diagrama de organización):

| OU | Cuentas |
|---|---|
| Security | Log Archive, Audit (las crea Control Tower) |
| Infrastructure | AFT management, Deployments |
| Workloads / Prod (transitoria) | Producción (cuenta actual) |
| Workloads / NonProd | Staging, Dev |
| Sandbox | Pool de Innovation Sandbox |

### Consecuencias

#### Positivas

* Pocas cuentas, fáciles de operar con un equipo pequeño.
* Separa entornos y reduce el radio de impacto entre ellos.

#### Negativas

* Dentro de producción no hay separación por dominio a nivel de cuenta; se compensa con VPC Lattice, IAM y segmentación ([ADR-017](#adr-017-vpc-lattice-en-lugar-de-transit-gateway), [ADR-033](#adr-033-reducción-del-alcance-pci-con-issuer-processor-y-segmentación)).

### Qué cambiaría la decisión

* Crecimiento del equipo a varios equipos autónomos por dominio, o un requisito regulatorio de aislar un dominio por cuenta.

---

## ADR-004: AFT sobre Control Tower para crear cuentas

### Contexto

El requisito de IaC es Terraform. Las opciones de AWS para crear y personalizar cuentas son Account Factory for Terraform (AFT) y Landing Zone Accelerator (LZA).

### Opciones consideradas

* LZA: más controles de cumplimiento, pero está construido en CDK y se configura con YAML propio.
* AFT: nativo de Terraform, sobre Control Tower.
* Organizations sin Control Tower, todo a mano en Terraform.

### Decisión

Control Tower con AFT (paso `O3`). Se descarta LZA porque es CDK y obligaría a mantener dos herramientas de IaC.

### Consecuencias

#### Positivas

* Una sola herramienta de IaC para la plataforma y las cargas.
* Cuentas nuevas con línea base (roles, presupuestos, etiquetas) desde el primer minuto.

#### Negativas

* AFT trae menos controles de cumplimiento listos que LZA; se completan con Config y Security Hub ([ADR-030](#adr-030-cloudtrail-organizacional-aws-config-y-security-hub)).
* AFT agrega su propia cuenta y su propio pipeline que operar.

### Qué cambiaría la decisión

* Que el requisito de Terraform se relajara y el peso regulatorio justificara LZA.

---

## ADR-005: Innovation Sandbox on AWS para los sandboxes

### Contexto

Los ingenieros necesitan experimentar sin tocar producción ni acumular costos olvidados.

### Opciones consideradas

* Una cuenta sandbox compartida.
* Innovation Sandbox on AWS con un pool de cuentas temporales.

### Decisión

Innovation Sandbox on AWS con un pool de cuentas pequeñas y limitadas creadas por AFT (paso `O6`). Innovation Sandbox mueve cuentas entre OUs y Control Tower lo reporta como drift; se acepta y se usa como señal de monitoreo.

### Consecuencias

#### Positivas

* Presupuesto y limpieza automática por cuenta prestada.
* Los experimentos no ensucian dev ni producción.

#### Negativas

* Alertas de drift en Control Tower que hay que saber filtrar.
* La solución no crea cuentas; el pool se crea y se mantiene aparte.

### Qué cambiaría la decisión

* Que el costo o la operación del pool supere su uso real; se volvería a una cuenta sandbox con presupuesto.

---

## ADR-006: Acceso humano de solo lectura en producción

### Contexto

Hoy los cambios se hacen a mano en la consola. Para que la IaC sea la fuente de verdad, nadie debe poder cambiar producción fuera del pipeline.

### Opciones consideradas

* Acceso de administrador con aprobación manual.
* Solo lectura para personas; cambios solo por roles de IaC; rol de emergencia.

### Decisión

En producción, todas las personas tienen solo lectura (vía IAM Identity Center). Solo los roles que asume el pipeline de Terraform y de despliegue pueden mutar recursos. Existe un rol *break-glass* con MFA, alerta inmediata y revisión posterior. Todo queda en CloudTrail.

### Consecuencias

#### Positivas

* La consola deja de ser una vía de cambio; el drift se vuelve excepción.
* Mínimo privilegio para humanos y cargas.

#### Negativas

* Las emergencias dependen del rol *break-glass* y de un pipeline rápido.
* Requiere disciplina y un pipeline confiable antes de quitar permisos.

### Qué cambiaría la decisión

* Nada a mediano plazo; solo se ajustaría qué lecturas se permiten (por ejemplo, ocultar datos sensibles en consola).

---

## ADR-007: SCPs en todas las cuentas excepto producción

### Contexto

Las SCPs limitan lo que puede hacer cualquier identidad de una cuenta. Aplicarlas de golpe a una cuenta de producción construida a mano puede romper flujos que nadie documentó.

### Opciones consideradas

* SCPs restrictivas en todas las cuentas, incluida producción.
* SCPs restrictivas en las cuentas nuevas; producción en una OU transitoria sin SCPs restrictivas.

### Decisión

Las cuentas nuevas (staging, dev, sandboxes, seguridad, infraestructura) tienen SCPs restrictivas desde el inicio (regiones permitidas, no desactivar CloudTrail/Config, no salir de la organización, etc.). Producción vive en una OU transitoria sin SCPs restrictivas; su control principal es IAM ([ADR-006](#adr-006-acceso-humano-de-solo-lectura-en-producción)).

### Consecuencias

#### Positivas

* Cero riesgo de que una SCP corte un flujo de producción no documentado.
* Las cuentas nuevas nacen gobernadas.

#### Negativas

* Producción depende de IAM y de la disciplina del pipeline, sin la red de seguridad de las SCPs.

### Qué cambiaría la decisión

* Una vez inventariados los flujos de producción, se podrían agregar SCPs mínimas de bajo riesgo (no desactivar CloudTrail, no salir de la organización) usando el análisis de *last accessed* de IAM.

---

## ADR-008: Todo a IaC: importar lo sensible, reconstruir lo efímero

### Contexto

Toda la infraestructura se creó a mano. Recrear recursos con estado o expuestos a clientes es riesgoso; recrear recursos sin estado es barato.

### Opciones consideradas

* Importar todo al estado de Terraform.
* Reconstruir todo desde cero.
* Mezcla según el tipo de recurso.

### Decisión

Se **importa** con bloques `import` todo lo que da la cara al cliente o es sensible: VPCs, ALBs, WAF, DNS, RDS, OpenSearch, KMS, DynamoDB, certificados. Se **reconstruye** lo efímero y sin estado: servicios y task definitions de ECS, configuración de clusters. La regla de importación es "plan sin cambios": un import solo se aplica si `terraform plan` no muestra diferencias.

### Consecuencias

#### Positivas

* Se adopta producción sin tocarla.
* Lo reconstruido queda limpio y estandarizado desde el inicio.

#### Negativas

* Importar es lento y manual; hay que generar y revisar la configuración de cientos de recursos (se puede acelerar con `terraform plan -generate-config-out` y asistentes de IA).

### Qué cambiaría la decisión

* Si un recurso importado no se puede describir sin cambios, se reemplaza con una estrategia blue/green en lugar de forzarlo.

---

## ADR-009: Terraform con los proveedores aws y awscc

### Contexto

El requisito es Terraform. Algunos servicios nuevos o capacidades poco comunes aparecen antes en el proveedor `awscc` (generado desde la API de Cloud Control) que en el proveedor `aws`.

### Decisión

Terraform con el proveedor `aws` por defecto y `awscc` para servicios o capacidades que aún no estén en `aws` (por ejemplo, opciones nuevas de OpenSearch Serverless NextGen).

### Consecuencias

#### Positivas

* Acceso temprano a capacidades nuevas sin salir de Terraform.

#### Negativas

* Dos proveedores con convenciones distintas; hay que documentar cuándo usar cada uno.

### Qué cambiaría la decisión

* Que todo lo necesario esté en el proveedor `aws`; `awscc` quedaría sin uso.

---

## ADR-010: Estructura del repositorio y estado de Terraform

### Contexto

No hay experiencia previa en el equipo con un layout de Terraform. Conviene seguir patrones conocidos.

### Decisión

* Layout basado en los patrones de `aws-ia` y `aws-samples`: `modules/` reutilizables y `live/<cuenta>/<componente>` desplegables.
* Backend S3 con bloqueo nativo (`use_lockfile`), un estado por cuenta y componente.
* Ver el [README de infra](../infra/README.md).

### Consecuencias

#### Positivas

* Estados pequeños: un `plan` afecta poco y es rápido.
* Patrones reconocibles por cualquier ingeniero nuevo.

#### Negativas

* Más estados que coordinar; las dependencias entre componentes se resuelven con datos remotos o SSM.

### Qué cambiaría la decisión

* Que el número de componentes crezca tanto que convenga una herramienta de orquestación (por ejemplo, Terragrunt o stacks de Terraform).

---

## ADR-011: La migración es una limpieza de la cuenta de producción

### Contexto

La guía de AWS para migraciones grandes clasifica cada carga con las 7R (retire, retain, rehost, relocate, repurchase, replatform, refactor). Aquí todo ya está en AWS; el problema es que producción y no productivo están mezclados.

### Decisión

* Producción: **retain**. Se queda en su cuenta y se adopta en IaC y gobierno.
* No productivo: sale a staging y dev ([ADR-012](#adr-012-rehost-o-rebuild-del-no-productivo-según-la-carga)).
* Lo huérfano: **retire**.
* La modernización (replatform, refactor) viene después, servicio por servicio ([ADR-013](#adr-013-modernización-del-cómputo-en-ecs) a [ADR-016](#adr-016-temporal-se-mantiene-self-hosted-durante-12-meses)).

Las herramientas de migración de servidores (MGN, AWS Transform) aplican a modernizaciones futuras y al no productivo donde haya servidores; producción son contenedores y datos administrados.

### Consecuencias

#### Positivas

* Cero downtime: lo que se mueve no es producción.
* Las herramientas de migración no tocan la infraestructura de producción.

#### Negativas

* Hay que separar con precisión qué es producción y qué no en una cuenta sin etiquetas; es el riesgo principal de la fase de inventario.

### Qué cambiaría la decisión

* Encontrar dependencias de producción hacia recursos no productivos (por ejemplo, un servicio productivo que lee una base "de pruebas"); ese recurso se reclasifica como producción.

---

## ADR-012: Rehost o rebuild del no productivo según la carga

### Contexto

El no productivo puede moverse tal cual (rehost/relocate) o reconstruirse desde IaC (rebuild).

### Decisión

Se decide por carga y se deja abierto a propósito. Criterio guía: si ya existe la definición en IaC o es sin estado, se reconstruye; si tiene estado o configuración difícil de reproducir, se mueve (snapshots compartidos, réplicas).

### Consecuencias

#### Positivas

* Flexibilidad para no bloquear la limpieza en las cargas difíciles.

#### Negativas

* Sin una regla única, hay que justificar cada caso.

### Qué cambiaría la decisión

* Un inventario que muestre que casi todo es reconstruible; entonces se reconstruye todo.

---

## ADR-013: Modernización del cómputo en ECS

### Contexto

Hay hasta 100 servicios en muchos clusters, sin datos de uso. El equipo ya conoce ECS.

### Opciones consideradas

* Migrar a EKS.
* Quedarse en ECS y optimizar.

### Decisión

Se queda en ECS (paso `2`). Después de la migración:

* Reorganizar clusters por dominio y entorno.
* Fargate y Graviton en todo lo posible; rightsizing con métricas reales.
* Fargate Spot donde la carga tolere interrupciones.
* A largo plazo y por carga: dividir monolitos, o pasar APIs simples a Lambda y API Gateway.

### Consecuencias

#### Positivas

* Menos operación (sin nodos que parchar) y menor costo por Graviton y rightsizing.
* Sin curva de aprendizaje de Kubernetes.

#### Negativas

* Algunas imágenes tendrán que compilarse para ARM64.

### Qué cambiaría la decisión

* Necesidades que solo cubra Kubernetes (operadores específicos, portabilidad multinube).

---

## ADR-014: Modernización de RDS según motor y propósito

### Contexto

Hasta 30 bases con motores, tamaños y configuraciones diversos y sin datos de uso.

### Decisión

Se evalúa base por base: rightsizing y autoscaling de almacenamiento, o migración a Aurora cuando el motor lo permite y el uso lo justifica. Los cambios se hacen con RDS Blue/Green Deployments o promoviendo réplicas de lectura de Aurora, para cortes de segundos.

### Consecuencias

#### Positivas

* Ahorro y elasticidad sin downtime perceptible.

#### Negativas

* Cada base requiere pruebas propias; es la parte más lenta del plan.

### Qué cambiaría la decisión

* Motores sin camino a Aurora; se quedan en RDS con rightsizing.

---

## ADR-015: OpenSearch Serverless NextGen

### Contexto

Hay dominios de OpenSearch administrados con configuración desconocida. La nueva generación de OpenSearch Serverless (GA en mayo de 2026) escala hasta cero y cobra por uso.

### Decisión

Migrar a OpenSearch Serverless NextGen como parte de la modernización, con doble escritura y cambio de alias para no tener downtime.

### Consecuencias

#### Positivas

* Sin clusters que dimensionar; costo alineado con el uso.

#### Negativas

* Servicio nuevo: hay que validar compatibilidad de funcionalidades y que esté en la calculadora de precios (si no, se estima aparte).

### Qué cambiaría la decisión

* Funcionalidades que solo existan en dominios administrados, o un uso constante tan alto que el aprovisionado sea más barato.

---

## ADR-016: Temporal se mantiene self-hosted durante 12 meses

### Contexto

Temporal orquesta los flujos de negocio y se asume self-hosted en ECS. El equipo lo conoce.

### Opciones consideradas

* Temporal Cloud.
* Reescribir flujos en Step Functions, MWAA o Glue.
* Mantenerlo como está.

### Decisión

Se mantiene self-hosted en ECS (paso `2`) durante los 12 meses. No se migra a Temporal Cloud (sería otra migración) ni se reescriben los flujos. A futuro se pueden mover flujos puntuales a Step Functions con EventBridge, o a Glue, si hay un caso de costo de largo plazo.

### Consecuencias

#### Positivas

* Se aprovecha la experiencia del equipo y no se agrega riesgo.

#### Negativas

* Se sigue operando Temporal y su persistencia.

### Qué cambiaría la decisión

* Que la operación de Temporal consuma una parte relevante del tiempo del equipo.

---

## ADR-017: VPC Lattice en lugar de Transit Gateway

### Contexto

Al separar entornos y segmentar servicios sensibles, los servicios necesitan conectarse entre VPCs y cuentas con control de acceso.

### Opciones consideradas

* Transit Gateway con reglas de red.
* VPC peering.
* VPC Lattice.

### Decisión

VPC Lattice para la comunicación entre servicios (paso `3`): service networks con políticas de autenticación de IAM, integrado de forma nativa con ECS.

### Consecuencias

#### Positivas

* Modelo de confianza cero entre servicios con IAM, sin administrar TLS en cada ALB interno.
* No importan los CIDR superpuestos entre VPCs.
* Útil para segmentar los servicios de tarjetas y el servicio de firma.

#### Negativas

* Más costoso que TGW o peering a igual tráfico; se acepta.

### Qué cambiaría la decisión

* Que el costo de Lattice resulte desproporcionado frente al tráfico real.

---

## ADR-018: Ingreso con CloudFront, WAF y ALB sin cambios

### Contexto

WAF ya está en uso. El ingreso de clientes es lo más sensible a cambios.

### Decisión

Se mantiene CloudFront, WAF y ALB (paso `1`). El uso de ALBs depende de cada servicio; la modernización puede consolidarlos.

### Consecuencias

#### Positivas

* Cero cambio visible para los clientes.

#### Negativas

* Se heredan las configuraciones actuales hasta que se importen y revisen.

### Qué cambiaría la decisión

* Necesidades nuevas de ingreso (por ejemplo, APIs privadas para socios).

---

## ADR-019: AWS Client VPN e IAM Identity Center para el equipo

### Contexto

El equipo usa una VPN de proveedor desconocido.

### Decisión

AWS Client VPN autenticado con IAM Identity Center para la red (paso `12`), e Identity Center para el acceso a AWS. Se corre en paralelo con la VPN actual hasta el corte.

### Consecuencias

#### Positivas

* Una sola identidad para red y AWS, auditada en CloudTrail.

#### Negativas

* Costo por conexión y por asociación de subred.

### Qué cambiaría la decisión

* Que el acceso a la red deje de ser necesario (todo por SSM Session Manager o Verified Access).

---

## ADR-020: DNS, IPs y direcciones de salida sin cambios

### Contexto

Los proveedores de pagos suelen tener en lista blanca las IPs de salida de Kova.

### Decisión

No se cambian DNS, IPs públicas ni NAT con Elastic IPs (paso `7`). Al quedarse producción en su cuenta, esto se cumple sin esfuerzo adicional.

### Consecuencias

#### Positivas

* Sin coordinación con proveedores ni riesgo de cortes por listas blancas.

#### Negativas

* Ninguna relevante.

### Qué cambiaría la decisión

* Un cambio de región o de cuenta de producción, que obligaría a coordinar nuevas IPs con cada proveedor.

---

## ADR-021: Llaves de firma de wallets con Nitro Enclaves, KMS y DynamoDB

### Contexto

Kova firma transacciones en Stellar (curva Ed25519) para un número alto de wallets. Las opciones de AWS son:

* KMS con una llave asimétrica por wallet: soporta Ed25519 y nunca expone la llave, pero cuesta alrededor de 1 USD por llave al mes, más cada solicitud de firma.
* CloudHSM: soporta Ed25519 (solo en clusters no FIPS), pero un hsm1.medium cuesta 1.60 USD por hora, unos 1,168 USD al mes en us-east-1, y se necesitan al menos dos para alta disponibilidad, 24/7.
* Secrets Manager por llave: costo por secreto al mes, sin aislamiento al usarla.
* Cifrado de sobre: llaves cifradas con una llave de KMS y guardadas en DynamoDB, descifradas solo dentro de un Nitro Enclave.

### Decisión

Cifrado de sobre con Nitro Enclaves (pasos `5` y `6`):

1. Cada llave de wallet se guarda cifrada en DynamoDB (o en la base RDS actual, si es donde viven hoy).
2. La llave de KMS que las cifra solo permite `Decrypt` cuando la solicitud trae un documento de atestación del enclave con la imagen esperada (`kms:RecipientAttestation:ImageSha384`).
3. El servicio de firma corre en un grupo de autoescalado de EC2 con Nitro Enclaves. ECS no documenta soporte para enclaves, así que va fuera de ECS.
4. El enclave descifra, firma y descarta la llave; la llave en claro nunca sale del enclave.
5. La llave de KMS es multi-Región y la tabla es global, para el DR ([ADR-031](#adr-031-dr-pilot-light-en-una-segunda-región-sin-drs)).

Es el patrón documentado por AWS para custodia de llaves de blockchain (blog de Web3 sobre Nitro Enclaves) y el recomendado por expertos de AWS para miles de wallets.

### Consecuencias

#### Positivas

* Costo de KMS independiente del número de wallets: una llave y solicitudes de descifrado.
* La llave en claro solo existe dentro del enclave, fuera del alcance del sistema operativo y de los administradores.
* DynamoDB escala sin límites prácticos de llaves.

#### Negativas

* Agrega EC2 al stack de cómputo (no es Fargate) y un ciclo de despliegue de imágenes de enclave.
* Cambiar la imagen del enclave exige actualizar la política de la llave.

### Qué cambiaría la decisión

* Pocas wallets (decenas): KMS con una llave asimétrica por wallet sería más simple.
* Volumen de firmas extremo o un requisito FIPS 140 nivel 3 dedicado: CloudHSM.

---

## ADR-022: Las llaves permanecen en la cuenta de producción

### Contexto

Lo ideal sería una cuenta de custodia separada. Pero las llaves de KMS no se pueden mover entre cuentas, y moverlas implicaría reprovisionar producción.

### Decisión

Las llaves y el servicio de firma se quedan en la cuenta de producción, aislados por red (Lattice), IAM y la política de la llave.

### Consecuencias

#### Positivas

* Sin riesgo de interrupción por mover llaves.

#### Negativas

* Menor aislamiento que una cuenta dedicada.

### Qué cambiaría la decisión

* Un requisito regulatorio explícito de separar la custodia en otra cuenta.

---

## ADR-023: Origen de las llaves: conservar, importar o generar fuera e importar

### Contexto

No se sabe dónde están hoy las llaves de las wallets.

### Decisión

* Si ya están en KMS: se conservan.
* Si están fuera de AWS: se importan (KMS admite importar material Ed25519).
* Si no existen: se generan fuera y se importan, para no quedar atados a un proveedor.

### Consecuencias

#### Positivas

* Portabilidad y sin cambios innecesarios.

#### Negativas

* Generar fuera exige una ceremonia de llaves y custodia del material original.

### Qué cambiaría la decisión

* Que no se requiera portabilidad; entonces se generan dentro del enclave.

---

## ADR-024: Secretos de configuración en Secrets Manager y SSM

### Contexto

Se asume que Kova ya sigue la práctica recomendada.

### Decisión

Secretos de configuración en Secrets Manager (con rotación donde aplique) y parámetros en SSM Parameter Store `SecureString` (paso `8`), cifrados con llaves de KMS por cuenta.

### Consecuencias

#### Positivas

* Sin secretos en código ni en variables de entorno planas.

#### Negativas

* Costo por secreto en Secrets Manager.

### Qué cambiaría la decisión

* Que el inventario muestre secretos fuera de estos servicios; se migran.

---

## ADR-025: CodePipeline y CodeBuild en una cuenta de Deployments

### Contexto

Se quiere CI/CD dentro de AWS. El código queda en GitHub (o su host actual). Hoy no hay pipelines: los cambios se hacen a mano.

### Opciones consideradas

* Pipelines dentro de cada cuenta de destino.
* Pipelines en la cuenta de AFT.
* Pipelines en una cuenta de Deployments dedicada, como recomienda la guía de AWS para entornos multicuenta.

### Decisión

CodePipeline y CodeBuild en una cuenta de Deployments (pasos `O7` y `11`), conectados a GitHub con CodeConnections. No se usa CodeCommit. Los pipelines despliegan en cada cuenta asumiendo roles de IaC; ECR replica las imágenes a las cuentas y a la región de DR.

Hay cuatro tipos de pipeline:

| Pipeline | Uno por | Etapas |
|---|---|---|
| Infraestructura (Terraform) | Cuenta y componente (`infra/live/...`) | Fuente → `fmt`, `validate` y revisión de políticas → `plan` guardado como artefacto → aprobación manual para producción → `apply` con un rol distinto al del `plan` |
| Aplicación | Servicio de ECS | Fuente → build de la imagen arm64 → pruebas → escaneo de la imagen (ECR con Amazon Inspector) → push a ECR con etiquetas inmutables → despliegue en dev → staging → aprobación → producción con blue/green nativo de ECS ([ADR-026](#adr-026-despliegues-bluegreen-nativos-de-ecs)) |
| Imagen del enclave | Servicio de firma | Build de la imagen del enclave → medición del PCR0 → Terraform actualiza la política de la llave de KMS con el nuevo PCR0 → renovación de instancias del grupo de autoescalado; aprobación de dos personas ([ADR-021](#adr-021-llaves-de-firma-de-wallets-con-nitro-enclaves-kms-y-dynamodb)) |
| Cuentas (AFT) | Solicitud de cuenta | Los administra AFT ([ADR-004](#adr-004-aft-sobre-control-tower-para-crear-cuentas)) |

### Consecuencias

#### Positivas

* Todo dentro de AWS y auditado en CloudTrail.
* Los pipelines no tienen credenciales permanentes en las cuentas destino.
* El `plan` revisado es exactamente lo que se aplica.

#### Negativas

* CodePipeline es menos flexible que otras herramientas de CI.
* Una cuenta más que operar.

#### Riesgos de seguridad y mitigaciones

La cuenta de Deployments puede asumir los roles que cambian producción, así que pasa a ser el objetivo más valioso de la organización. Quien la controle, o controle un repositorio, puede desplegar en producción.

| Riesgo | Mitigación |
|---|---|
| Compromiso de la cuenta de Deployments | SCPs restrictivas; ninguna persona con escritura; alertas de CloudTrail sobre cambios en pipelines, roles y conexiones |
| Abuso de los roles de IaC en las cuentas destino | Política de confianza que solo admite el rol de cada pipeline (con condición `aws:SourceAccount`); roles separados de `plan` (solo lectura) y `apply`; permisos mínimos por componente |
| Cambio malicioso o erróneo desde el repositorio (cadena de suministro) | CodeConnections limitado a repositorios específicos; ramas protegidas y revisión obligatoria en GitHub; aprobación manual antes de producción |
| Imagen o dependencia comprometida | Escaneo de imágenes, etiquetas inmutables en ECR y, opcionalmente, firma de imágenes |
| Filtración de artefactos (planes de Terraform con datos sensibles) | Buckets de artefactos cifrados con KMS, acceso solo para los roles del pipeline, ciclo de vida corto |
| Cambio de la imagen del enclave para robar llaves | El PCR0 solo cambia con aprobación de dos personas y queda registrado en CloudTrail |

### Qué cambiaría la decisión

* Que el equipo dependa mucho de GitHub Actions; se usaría OIDC hacia los mismos roles de IaC, con las mismas mitigaciones.
* Preferir menos cuentas: los pipelines podrían vivir en la cuenta de AFT, aceptando concentrar más privilegios en ella.

---

## ADR-026: Despliegues blue/green nativos de ECS

### Contexto

ECS ahora soporta blue/green de forma nativa, sin CodeDeploy.

### Decisión

Despliegues blue/green nativos de ECS (paso `11`), con *circuit breaker* y *rollback* automático. Sin CodeDeploy.

### Consecuencias

#### Positivas

* Menos piezas y configuración en Terraform sin archivos AppSpec.

#### Negativas

* Según la documentación consultada, el blue/green nativo cambia todo el tráfico de una vez (sin *canary* ni lineal); se revisa si eso cambió.

### Qué cambiaría la decisión

* Servicios que requieran *canary*; se usaría CodeDeploy solo para ellos.

---

## ADR-027: OpenTelemetry como capa de desacople de observabilidad

### Contexto

Hoy se usa New Relic y se evalúa cambiar de herramienta. Cambiar de herramienta suele implicar re-instrumentar todo.

### Decisión

Todo servicio emite logs, métricas y trazas con OpenTelemetry hacia un colector ADOT (paso `9`). New Relic se mantiene durante la migración. Luego se evalúan, con los mismos datos, CloudWatch y CloudWatch Omni, Amazon Managed Grafana con Managed Prometheus, y Datadog como un candidato más.

### Consecuencias

#### Positivas

* Cambiar de herramienta pasa a ser cambiar el destino del colector.
* Permite enviar a dos herramientas en paralelo durante la evaluación.

#### Negativas

* Instrumentar con OpenTelemetry es un esfuerzo inicial en cada servicio.

### Qué cambiaría la decisión

* Nada; la elección de herramienta final queda fuera de esta decisión.

---

## ADR-028: Retención de logs y archivo en S3 con Athena

### Contexto

Los logs sin retención crecen sin control y son una de las fuentes de costo que más se escapa.

### Decisión

Todo grupo de logs y almacén de trazas tiene retención definida (paso `10`). Los logs que hay que conservar más tiempo se exportan a S3 con ciclo de vida y se consultan con Athena.

### Consecuencias

#### Positivas

* Costo de logs predecible.

#### Negativas

* Consultar logs viejos es más lento (Athena en lugar de la herramienta de observabilidad).

### Qué cambiaría la decisión

* Requisitos regulatorios de retención; ajustan los plazos, no el mecanismo.

---

## ADR-029: FinOps: etiquetado obligatorio, presupuestos y anomalías

### Contexto

Sin etiquetas no se sabe qué cuesta cada servicio ni qué es producción.

### Decisión

* Etiquetas obligatorias en todo recurso (políticas de etiquetas de Organizations y validación en el pipeline).
* AWS Budgets por cuenta, alertas de facturación y Cost Anomaly Detection.
* Topes de costo en sandboxes y dev.

### Consecuencias

#### Positivas

* Costo por servicio y por entorno visible; detecta gastos inesperados pronto.

#### Negativas

* Etiquetar lo existente es trabajo manual en la fase de inventario.

### Qué cambiaría la decisión

* Nada; es la base para estimar y recortar costos.

---

## ADR-030: CloudTrail organizacional, AWS Config y Security Hub

### Contexto

Sin auditoría centralizada no hay forma de saber quién cambió qué ni de detectar desviaciones.

### Decisión

CloudTrail organizacional hacia Log Archive, AWS Config para detectar configuraciones incorrectas y drift (con el paquete de conformidad de PCI DSS) y Security Hub en la cuenta Audit (paso `13`). El detalle se deja abierto a propósito.

### Consecuencias

#### Positivas

* Trazabilidad completa y hallazgos centralizados.

#### Negativas

* Costo de Config por elemento de configuración registrado.

### Qué cambiaría la decisión

* Nada; el alcance de reglas se ajusta con el uso.

---

## ADR-031: DR pilot light en una segunda región, sin DRS

### Contexto

Se asume RTO de 1 hora (por las dependencias entre sistemas) y RPO de 5 minutos. AWS Elastic Disaster Recovery (DRS) replica servidores con agente; no cubre ECS, Fargate, RDS ni OpenSearch, y AWS recomienda la copia entre regiones de RDS en lugar de DRS para RDS.

### Opciones consideradas

* Pilot light: datos replicados siempre, cómputo creado al fallar.
* Warm standby: cómputo mínimo encendido en la segunda región.
* Activo-activo multirregión.

### Decisión

Pilot light por costo (paso `14`):

* Réplicas de RDS entre regiones (Aurora Global Database tras la modernización).
* Tabla global de DynamoDB y llave réplica de KMS para las wallets.
* Replicación de ECR.
* Los servicios de ECS, incluido Temporal, se crean con Terraform solo durante una conmutación.

### Consecuencias

#### Positivas

* Cumple RPO de 5 minutos y RTO de 1 hora con el menor costo fijo.

#### Negativas

* El RTO depende de que el `terraform apply` de la región de DR esté probado; hay que ensayarlo.

### Qué cambiaría la decisión

* Un RTO cercano a cero: warm standby o activo-activo, con su costo.

---

## ADR-032: No tocar la infraestructura blockchain

### Contexto

Se asume Stellar. No hay información de nodos propios ni de Horizon.

### Decisión

No se toca la integración con la red blockchain. Lo único en alcance son las llaves de firma ([ADR-021](#adr-021-llaves-de-firma-de-wallets-con-nitro-enclaves-kms-y-dynamodb)).

### Consecuencias

#### Positivas

* Sin riesgo sobre la pieza más crítica y menos conocida.

#### Negativas

* Posibles mejoras (nodos propios, redundancia de proveedores RPC) quedan fuera.

### Qué cambiaría la decisión

* Contexto sobre cómo se conecta Kova a Stellar hoy.

---

## ADR-033: Reducción del alcance PCI con issuer-processor y segmentación

### Contexto

Kova emite tarjetas, así que aplica PCI DSS. El alcance es todo sistema que almacena, procesa o transmite datos de tarjeta, más lo conectado a ellos.

### Opciones consideradas

* Kova maneja los datos de tarjeta en su propia infraestructura.
* Un issuer-processor (tipo Pomelo, Marqeta o Galileo) guarda los datos de tarjeta y Kova solo tokens.
* Una cuenta dedicada para el entorno de datos de tarjeta.

### Decisión

Issuer-processor más segmentación dentro de la cuenta de producción (paso `4`): los pocos servicios que hablan con el procesador quedan en su propia service network de Lattice, con políticas de IAM, security groups y etiquetas. Paquete de conformidad PCI DSS de AWS Config y el reporte de cumplimiento PCI de AWS (AWS Artifact) para la parte de responsabilidad compartida.

### Consecuencias

#### Positivas

* Alcance PCI mínimo y nada se mueve.

#### Negativas

* Dependencia del procesador.

### Qué cambiaría la decisión

* Que Kova necesite manejar datos de tarjeta directamente; se evaluaría una cuenta dedicada como paso de modernización.
