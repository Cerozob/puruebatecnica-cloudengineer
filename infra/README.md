# Infraestructura como código (esqueleto)

Esqueleto de Terraform de la [arquitectura objetivo](../docs/arquitectura.md). No está pensado para desplegarse tal cual: muestra la estructura, las convenciones y ejemplos concretos de las decisiones de [decisiones_full.md](../docs/decisiones_full.md). Todos los componentes pasan `terraform fmt` y `terraform validate`.

## Estructura

Basada en los patrones de `aws-ia` y `aws-samples` ([ADR-010](../docs/decisiones_full.md#adr-010-estructura-del-repositorio-y-estado-de-terraform)): módulos reutilizables en `modules/` y componentes desplegables en `live/<cuenta>/<componente>`, cada uno con su propio estado.

```
infra/
├── modules/
│   ├── ecs-service/          # Ejemplo principal: servicio ECS de la plataforma objetivo
│   ├── signing-enclave/      # Servicio de firma: Nitro Enclaves + KMS + DynamoDB global
│   └── search-collection/    # OpenSearch Serverless con el proveedor awscc
└── live/
    ├── management/
    │   └── organization/     # Organización, OUs, SCPs, políticas de etiquetas, Control Tower
    ├── aft/                  # Account Factory for Terraform
    └── prod/                 # Cuenta actual, adoptada en IaC
        ├── network/          # VPC, NAT y Elastic IP importados + service networks de Lattice
        ├── data/             # RDS importado + réplica en la región de DR
        ├── services/
        │   └── payments-api/ # Uso del módulo ecs-service
        ├── signing/          # Uso del módulo signing-enclave
        └── search/           # Uso del módulo search-collection
```

Las cuentas staging, dev, Deployments y el pool de sandboxes se piden a AFT desde su propio repositorio (`aft-account-request`), un archivo por cuenta.

## Convenciones

* **Proveedores:** `aws` por defecto y `awscc` para capacidades nuevas, como OpenSearch Serverless ([ADR-009](../docs/decisiones_full.md#adr-009-terraform-con-los-proveedores-aws-y-awscc)).
* **Estado:** backend S3 con bloqueo nativo (`use_lockfile = true`), un estado por cuenta y componente. Los componentes comparten identificadores por SSM Parameter Store, no leyendo el estado de otros.
* **Acceso:** el pipeline asume un rol de IaC en cada cuenta (`deploy_role_arn`); ninguna persona aplica cambios en producción ([ADR-006](../docs/decisiones_full.md#adr-006-acceso-humano-de-solo-lectura-en-producción)).
* **Etiquetas:** `default_tags` del proveedor con `environment`, `component`, `owner` y `managed-by` ([ADR-029](../docs/decisiones_full.md#adr-029-finops-etiquetado-obligatorio-presupuestos-y-anomalías)).
* **Adopción de producción:** bloques `import` y `prevent_destroy` para lo sensible; un import solo se aplica con un plan sin cambios ([ADR-008](../docs/decisiones_full.md#adr-008-todo-a-iac-importar-lo-sensible-reconstruir-lo-efímero)).

## Ejemplo principal: `modules/ecs-service`

Un servicio de ECS con las decisiones de la plataforma aplicadas:

* Fargate sobre Graviton (`ARM64`) y una proporción opcional en Fargate Spot ([ADR-013](../docs/decisiones_full.md#adr-013-modernización-del-cómputo-en-ecs)).
* Despliegue blue/green nativo de ECS con *circuit breaker* y *rollback* ([ADR-026](../docs/decisiones_full.md#adr-026-despliegues-bluegreen-nativos-de-ecs)).
* Registro en VPC Lattice para el tráfico entre servicios ([ADR-017](../docs/decisiones_full.md#adr-017-vpc-lattice-en-lugar-de-transit-gateway)).
* Colector ADOT como *sidecar* para OpenTelemetry ([ADR-027](../docs/decisiones_full.md#adr-027-opentelemetry-como-capa-de-desacople-de-observabilidad)).
* Grupo de logs con retención ([ADR-028](../docs/decisiones_full.md#adr-028-retención-de-logs-y-archivo-en-s3-con-athena)).
* Rol de tarea propio con una política de mínimo privilegio, y rol de ejecución que solo lee los secretos del servicio.
* Autoescalado por CPU.

`live/prod/services/payments-api` muestra cómo se usa.

## Validar

```bash
cd infra/live/prod/services/payments-api
```

```bash
terraform init -backend=false
```

```bash
terraform validate
```
