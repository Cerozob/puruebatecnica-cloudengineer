# Estimado de Costos y Recortes

* Autor: **Camilo Rozo**

* **Calculadora de AWS:** _enlaces pendientes_. Las líneas de [costos.xlsx](costos.xlsx) y [costos-actual.xlsx](costos-actual.xlsx) sirven de especificación para cargarlas.
* **Archivos:** cada libro tiene una hoja `Supuestos` (todas las entradas) y una hoja `Estimado` (líneas con fórmulas). El del objetivo tiene además una hoja `Recortes`.
* **Servicios fuera de la calculadora:** OpenSearch Serverless NextGen y CloudWatch Omni se calculan solo en el archivo, con los precios de su página.

## Base del estimado

* Región us-east-1, en USD.
* Solo precios bajo demanda: sin Spot, sin Savings Plans ni instancias reservadas, sin capa gratuita.
* Todo se trata como producción ([S-19](decisiones_short.md#suposiciones)).
* **Cómputo:** 100 servicios de ECS con 2 vCPU y 4 GB cada uno, como cota superior.
* **Balanceadores:** un ALB por servicio.
* **Bases:** 30 instancias grandes de RDS PostgreSQL en una zona.
* **OpenSearch:** 100 GB.
* **Firmas:** 10 millones al mes, con dos `c9g.large` para el servicio de firma.
* **Picos:** de 3 veces, una semana cuatro veces al año, es decir un mes de pico al año. El cómputo y el tráfico usan un factor promedio de (11 + 3) / 12 ≈ 1.17.
* **Precios unitarios:** son los de la página de precios de cada servicio y se confirman al cargar la calculadora.

## Costo mensual: actual frente a objetivo

| Categoría | Actual (USD / mes) | Objetivo (USD / mes) | Diferencia |
|---|---|---|---|
| Cómputo | 8,409 | 6,845 | −1,564 |
| Red | 2,628 | 5,444 | +2,816 |
| Datos | 12,298 | 11,905 | −393 |
| Llaves y secretos | 130 | 142 | +12 |
| Observabilidad | 1,505 | 1,175 | −330 |
| Gobierno | 0 | 260 | +260 |
| CI/CD | 0 | 246 | +246 |
| DR | 0 | 11,262 | +11,262 |
| Sandboxes | 0 | 500 | +500 |
| **Total mensual** | **~24,970** | **~37,780** | **+12,810 (+51 %)** |
| **Total anual** | **~299,650** | **~453,340** | |

**Lo que agrega el objetivo:**

* El DR en pilot light, que hoy no existe: casi toda la diferencia es el costo de tener las 30 bases replicadas en otra región.
* VPC Lattice, CloudFront y AWS Client VPN.
* El gobierno (Config, Security Hub), los pipelines y los sandboxes.

**Lo que ahorra:**

* Fargate en Graviton.
* La retención de logs con archivo en S3.
* OpenSearch Serverless en lugar de un dominio con nodos fijos.

Sin DR, el objetivo costaría casi lo mismo que hoy, con mucho más control.

**No incluye:** licencias de New Relic u otra herramienta de APM, la licencia de la VPN actual, el plan de soporte de AWS, impuestos ni el costo del equipo.

## Dos recortes concretos y el riesgo que agregan

| Recorte | Ahorro (USD / mes) | Riesgo que agrega |
|---|---|---|
| **1. DR solo con copias de AWS Backup entre regiones**, sin réplicas vivas de RDS ([ADR-031](decisiones_full.md#adr-031-dr-pilot-light-en-una-segunda-región-sin-drs)) | ~9,570 | El RPO pasa de minutos a horas (la frecuencia de las copias) y el RTO crece porque hay que restaurar 30 bases antes de levantar los servicios; el RTO de 1 hora deja de cumplirse. |
| **2. Reemplazar VPC Lattice por ECS Service Connect** ([ADR-017](decisiones_full.md#adr-017-vpc-lattice-en-lugar-de-transit-gateway)) | ~1,740 | Se pierde la autorización de IAM entre servicios: la segmentación del servicio de firma y de los servicios de tarjetas (PCI) queda solo en security groups, y la comunicación entre VPCs o cuentas vuelve a depender del enrutamiento de red. |

Otros candidatos evaluados, en la hoja `Recortes`:

| Candidato | Ahorro (USD / mes) | Riesgo |
|---|---|---|
| Consolidar los 100 ALB en unos 10 | ~1,480 | Mayor radio de impacto si falla un ALB compartido. |
| Fargate Spot para el 30 % de los servicios | ~1,410 | Interrupciones con dos minutos de aviso. |
| Compute Savings Plan a un año | ~1,370 | Compromiso de gasto aunque el uso baje. |
