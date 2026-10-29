# Documento de reporte de uso de IA Generativa

* Autor: **Camilo Rozo**

<!-- Borrador generado con IA a partir de la estructura del reporte anterior. Reescribir en palabras propias antes de entregar. -->

## 1. Herramientas de IA Generativa Utilizadas

* Claude Code (sesión en la nube, con modo de planeación)
* Servidores MCP conectados a Claude Code:
  * AWS Knowledge / AWS MCP, para consultar documentación oficial de AWS
  * AWS Pricing, para precios unitarios
  * Eraser, para escribir los diagramas como código

## 2. Qué tareas apoyo con IA

* Investigación: verificar contra la documentación de AWS cada servicio y cada afirmación (curvas soportadas por KMS y CloudHSM, alcance de DRS, Nitro Enclaves, VPC Lattice con ECS, novedades como OpenSearch Serverless NextGen y CloudWatch Omni).
* Redacción de borradores: decisiones (ADRs), plan de migración y modernización, controles de seguridad, narrativas de los diagramas y este documento.
* Código de los diagramas en Eraser (solo diagramas como código, sin los generadores de IA de Eraser) y el esqueleto de Terraform.

La numeración de los diagramas, su revisión visual y la exportación las hice yo.

## 3. Qué validaciones realizo sobre lo generado

* Cada decisión la tomé yo; el agente solo la cuestionaba contra las buenas prácticas de AWS y yo decidía si cambiarla.
* Las afirmaciones técnicas se contrastaron con la documentación oficial de AWS. Cuando la fuente no era accesible desde el agente (por ejemplo, un hilo de re:Post), revisé la fuente yo mismo.
* Los precios clave los revisé en la calculadora de AWS (por ejemplo, el costo de CloudHSM).
* El esqueleto de Terraform se validó con `terraform fmt` y `terraform validate`.

## 4. Qué riesgos identifiqué

* **Afirmaciones plausibles pero falsas:** por ejemplo, proponer AWS Elastic Disaster Recovery para cargas que no cubre (ECS, RDS). Se detectó al verificar en la documentación.
* **Fuentes mal usadas:** citar un artículo que habla de otra cosa (un blog de análisis de wallets en DynamoDB no trata de custodia de llaves).
* **Sobreingeniería y sobredocumentación:** tendencia a agregar más servicios, detalle y texto del necesario para una prueba de diseño.
* **Desviación:** ante la ambigüedad, el agente asume; por eso las suposiciones quedaron en una lista explícita.

## 5. Cómo evité depender ciegamente de la herramienta

* Diseñé y decidí yo; el agente actuó como contraparte que cuestiona, con la regla "yo decido, tú me retas".
* Respondí siempre con mis palabras en lugar de aceptar opciones prefabricadas.
* Trabajé en modo de planeación, revisando cada paso antes de ejecutarlo.
* Pedí fuentes oficiales para cada afirmación relevante y revisé por mi cuenta las que el agente no pudo abrir.
