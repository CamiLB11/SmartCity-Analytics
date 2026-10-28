# SmartCity Analytics: modelo documental de MongoDB

## 1. Objetivo

Este documento describe el modelo documental empleado para almacenar las lecturas del conjunto de datos y preparar las colecciones de eventos operativos y alertas.

La base de datos se llama `smartcity_analytics` y contiene tres colecciones:

- `sensor_readings`: lecturas de medidores con datos del edificio y variables meteorológicas.
- `sensor_events`: estructura destinada a eventos relacionados con los sensores.
- `alerts`: estructura destinada a alertas generadas por el sistema.

Las lecturas se importan desde los cuatro archivos `trainM0.csv`, `trainM1.csv`, `trainM2.csv` y `trainM3.csv`. Las colecciones de eventos y alertas se crean vacías porque esos registros no vienen incluidos como datos de eventos o alertas en los CSV de lecturas.

## 2. Archivos de datos: por qué se usan los cuatro `trainM*.csv`

El ZIP original contiene cinco CSV:

| Archivo | Filas de datos | Representación |
|---|---:|---|
| `Dataset.csv` | 20,216,100 | Con columnas `m0`, `m1`, `m2` y `m3` |
| `trainM0.csv` | 12,060,910 | Lecturas del medidor tipo 0, con campo `meter_reading` |
| `trainM1.csv` | 4,182,440 | Lecturas del medidor tipo 1, con campo `meter_reading` |
| `trainM2.csv` | 2,708,713 | Lecturas del medidor tipo 2, con campo `meter_reading` |
| `trainM3.csv` | 1,264,037 | Lecturas del medidor tipo 3, con campo `meter_reading` |

La suma de los cuatro archivos `trainM*.csv` es 20,216,100 filas, la misma cantidad que `Dataset.csv`.

Los archivos `trainM0.csv` a `trainM3.csv` dividen los registros por tipo de medidor y utilizan un único campo de lectura, `meter_reading`. `Dataset.csv` presenta las lecturas mediante las columnas `m0`, `m1`, `m2` y `m3`.

Por eso, el script importa los cuatro archivos `trainM*.csv`: juntos representan las 20,216,100 filas y ofrecen una estructura uniforme para filtrar por `meter` y consultar el valor en `meter_reading`.

No se importa también `Dataset.csv`, para evitar cargar la misma población de registros mediante dos representaciones diferentes.

## 3. Colección `sensor_readings`

Cada documento representa una lectura de un medidor en un edificio y una marca temporal.

### Campos originales conservados

| Campo | Descripción |
|---|---|
| `building_id` | Identificador del edificio |
| `meter` | Tipo de medidor, entre 0 y 3 |
| `meter_reading` | Valor original de la lectura |
| `site_id` | Identificador del sitio |
| `primary_use` | Uso principal del edificio |
| `square_feet` | Área del edificio en pies cuadrados |
| `year_built` | Año de construcción |
| `floor_count` | Cantidad de pisos |
| `air_temperature` | Temperatura del aire |
| `cloud_coverage` | Cobertura nubosa |
| `dew_temperature` | Temperatura del punto de rocío |
| `precip_depth_1_hr` | Profundidad de precipitación en una hora |
| `sea_level_pressure` | Presión al nivel del mar |
| `wind_direction` | Dirección del viento |
| `wind_speed` | Velocidad del viento |
| `unixtimestamp` | Marca temporal Unix original, en segundos |

Los campos numéricos vacíos se guardan como `null`. Los campos adicionales presentes en los CSV también se conservan.

### Campos añadidos por la carga

| Campo | Descripción |
|---|---|
| `_id` | Identificador estable formado por `building_id`, `meter` y `unixtimestamp` |
| `timestamp` | Fecha BSON obtenida al convertir `unixtimestamp` a fecha |
| `sensor_id` | Identificador derivado según la convención `MTR-B<building_id>-T<meter>` |
| `value` | Alias numérico de `meter_reading` para facilitar consultas que utilicen el nombre genérico `value` |
| `source` | Nombre del CSV de origen |
| `source_file` | Nombre del CSV de origen |

Los campos `meter_reading` y `unixtimestamp` se conservan: no se reemplazan por los campos añadidos.

La unidad física de `meter_reading` no se asigna porque debe confirmarse en la documentación de la fuente.

### Ejemplo de estructura del documento

El siguiente ejemplo es ilustrativo. La carga no inserta este ejemplo manualmente, sino que crea documentos a partir de las filas de los CSV.

```javascript
{
  _id: "46_0_1451606400",
  building_id: 46,
  meter: 0,
  meter_reading: 53,
  value: 53,
  site_id: 0,
  primary_use: "Retail",
  square_feet: 9045,
  unixtimestamp: 1451606400,
  timestamp: ISODate("2016-01-01T00:00:00.000Z"),
  sensor_id: "MTR-B46-T0",
  source: "trainM0.csv",
  source_file: "trainM0.csv"
}