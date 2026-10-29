# Controles de Seguridad: Primeros 90 Días

* Autor: **Camilo Rozo**

Principios: nadie cambia producción a mano, todo queda registrado en CloudTrail, y personas y cargas tienen el mínimo privilegio. Las SCPs gobiernan todas las cuentas de la organización salvo producción, que se controla con IAM mientras se inventaría ([ADR-007](decisiones_full.md#adr-007-scps-en-todas-las-cuentas-excepto-producción)).

| Área | Días 0 a 30 | Días 31 a 60 | Días 61 a 90 |
|---|---|---|---|
| **Accesos** | IAM Identity Center como única entrada; MFA obligatorio; rol *break-glass* con alerta; inventario de usuarios IAM y llaves de acceso. | Permission sets de solo lectura en producción; quitar usuarios IAM y llaves de acceso de larga duración. | Sin permisos de escritura humanos en producción; roles de cargas revisados con IAM Access Analyzer (permisos no usados). |
| **Secretos y llaves** | Inventario de secretos y de dónde están las llaves de wallets. | Todo secreto en Secrets Manager / SSM con llave de KMS por cuenta; rotación donde aplique. | Política de la llave de wallets limitada a la atestación del enclave ([ADR-021](decisiones_full.md#adr-021-llaves-de-firma-de-wallets-con-nitro-enclaves-kms-y-dynamodb)). |
| **Red** | Revisar security groups abiertos a internet y reglas del WAF. | AWS Client VPN con Identity Center en paralelo a la VPN actual. | Servicios sensibles (tarjetas, firma) detrás de VPC Lattice con políticas de IAM. |
| **Auditoría** | CloudTrail organizacional hacia Log Archive; AWS Config en todas las cuentas. | Security Hub en la cuenta Audit; paquete de conformidad PCI DSS de Config. | Alertas sobre acciones críticas: uso de *break-glass*, cambios de IAM o de políticas de llaves, cambios fuera del pipeline. |
| **Respuesta a incidentes** | Guardia 24/7 con dos turnos y canal de escalamiento definido. | Runbooks para credenciales filtradas, llave comprometida y cambio no autorizado. | Simulacro de incidente y revisión posterior. |

## Mínimo privilegio

* **Personas:** permission sets por función (lectura, operación en dev, administración de plataforma) asignados por grupo, nunca por usuario. En producción solo lectura; el rol *break-glass* requiere MFA, deja alerta y se revisa después de cada uso.
* **Cargas:** un rol por servicio de ECS con solo las acciones y recursos que usa. El servicio de firma es el único que puede pedir el descifrado de las llaves de wallets, y solo desde el enclave.
* **Pipelines:** los roles de IaC se asumen solo desde la cuenta de Deployments, sin credenciales permanentes.

## SCPs en las cuentas que no son producción

* Solo regiones aprobadas.
* Prohibido desactivar CloudTrail, Config o Security Hub, o salir de la organización.
* Prohibido crear usuarios IAM o llaves de acceso.
* Recursos sin etiquetas obligatorias rechazados.
* Topes de costo en sandboxes (Innovation Sandbox) y dev (Budgets).
