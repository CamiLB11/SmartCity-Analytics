# SmartCity Analytics - Arquitectura de Datos (Fase 1)

Plataforma de gestión y análisis de datos urbanos diseñada para integrar información proveniente de sensores IoT, estaciones meteorológicas y medidores de infraestructura en una ciudad inteligente.

## Arquitectura de Almacenamiento

Esta fase inicial establece los cimientos de un ecosistema de almacenamiento híbrido, optimizado para diferentes naturalezas de datos:

*   **PostgreSQL (Modelo Relacional):** Gestiona los datos estructurados, entidades maestras y de referencia. Mantiene la integridad referencial del inventario de sensores, zonificación urbana, características de los edificios y el registro histórico unificado de condiciones climáticas.
*   **MongoDB (Modelo Documental):** Administra la ingesta semiestructurada de telemetría IoT, permitiendo flexibilidad en los esquemas para eventos variables y lecturas continuas de diferentes tipos de dispositivos.

## Estructura del Repositorio (Core SQL)

*   `Esquema_smartcity.sql`: Script DDL responsable de desplegar la base de datos relacional, incluyendo llaves primarias/foráneas, índices (B-Tree y BRIN) y validaciones de integridad.
*   `Carga_dataset.sql`: Script DML que implementa el motor de *Staging*. Utiliza el comando `COPY` para ingestas masivas de datos crudos (CSV) y rutinas de normalización hacia el modelo final.
*   `Consultas_PostgreSQL.sql`: Set de operaciones analíticas. Implementa agregaciones complejas, *Common Table Expressions* (CTEs), *Window Functions*, vistas materializadas y funciones almacenadas para la extracción de métricas urbanas.

## Flujo de Ingesta y Procesamiento

1.  **Staging (Carga Cruda):** Los volúmenes masivos de datos (ej. millones de registros de consumo energético y clima) se depositan temporalmente en tablas planas diseñadas para una ingesta de alta velocidad.
2.  **Normalización (DML):** A través de scripts automatizados y manejo de conflictos (`ON CONFLICT DO NOTHING`), la información se distribuye a las tablas dimensionales (ej. `ubicacion`, `categoria_sensor`) y a las tablas transaccionales (`sensor`, `lectura_sensor`).
3.  **Extracción de Valor:** Ejecución de consultas estratégicas para auditar la actividad de los dispositivos, identificar zonas críticas y extraer estadísticas vitales del comportamiento de la ciudad.