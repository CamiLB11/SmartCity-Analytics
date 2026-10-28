SET search_path TO smartcity, public;

-- 1. Sensores por tipo
SELECT c.nombre_categoria, COUNT(s.id_sensor) AS cantidad_sensores
FROM sensor s
JOIN categoria_sensor c ON s.id_categoria = c.id_categoria
GROUP BY c.nombre_categoria
ORDER BY cantidad_sensores DESC;
/* Resultados de prueba:
nombre_categoria  | cantidad_sensores
Electricidad      | 1413
Agua fría         | 498
Vapor             | 324
Agua caliente     | 145
*/


-- 2. Sensores por ubicación
SELECT u.nombre_zona, COUNT(s.id_sensor) AS total_sensores
FROM sensor s
JOIN edificio e ON s.building_id = e.building_id
JOIN ubicacion u ON e.id_ubicacion = u.id_ubicacion
GROUP BY u.nombre_zona
ORDER BY total_sensores DESC;

/* Resultados de prueba:
"nombre_zona"	"total_sensores"
"Zona 13"	| 309
"Zona 9"	| 306
"Zona 2"	| 289
"Zona 14"	| 288
"Zona 3"	| 274
"Zona 15"	| 250
"Zona 0"	| 129
"Zona 4"	| 91
"Zona 5"	| 89
"Zona 6"	| 80
"Zona 8"	| 70
"Zona 1"	| 63
"Zona 10"	| 50
"Zona 7"	| 42
"Zona 12"	| 36
"Zona 11"	| 14
*/

-- 3. Cantidad de sensores activos e inactivos
SELECT estado, COUNT(id_sensor) AS total
FROM sensor
GROUP BY estado;

/* Resultados de prueba:
"estado"	"total"
"ACTIVO"	2380
*/

-- 4. Número de sensores por organismo responsable (Usando LEFT JOIN)
SELECT o.nombre AS organismo, COUNT(s.id_sensor) AS total_sensores
FROM organismo_responsable o
LEFT JOIN sensor s ON o.id_organismo = s.id_organismo
GROUP BY o.nombre;

/* Resultados de prueba:
"organismo"	"total_sensores"
"Unidad de Gestión Energética SmartCity"	2380
*/

-- 5. Ubicaciones con mayor cantidad de sensores (Uso de CTE y Window Function)
WITH ConteoSensores AS (
    SELECT 
        u.nombre_zona, 
        COUNT(s.id_sensor) AS total,
        RANK() OVER(ORDER BY COUNT(s.id_sensor) DESC) as ranking
    FROM sensor s
    JOIN edificio e ON s.building_id = e.building_id
    JOIN ubicacion u ON e.id_ubicacion = u.id_ubicacion
    GROUP BY u.nombre_zona
)
SELECT nombre_zona, total 
FROM ConteoSensores 
WHERE ranking <= 5;

/* Resultados de prueba:
"nombre_zona"	"total"
"Zona 13"	309
"Zona 9"	306
"Zona 2"	289
"Zona 14"	288
"Zona 3"	274
*/

-- 6. Sensores instalados por año
SELECT EXTRACT(YEAR FROM fecha_instalacion) AS anio_instalacion, COUNT(id_sensor) AS cantidad
FROM sensor
GROUP BY anio_instalacion
ORDER BY anio_instalacion;

/* Resultados de prueba:
"anio_instalacion"	"cantidad"
2016	2380
*/

-- 7. Sensores sin actividad registrada (Subconsulta usando NOT EXISTS)
SELECT s.id_sensor, s.nombre
FROM sensor s
WHERE NOT EXISTS (
    SELECT 1 
    FROM lectura_sensor l 
    WHERE l.id_sensor = s.id_sensor
);

/* Resultados de prueba:
"id_sensor"	"nombre"
19	"Sensor-B1091-M0"
20	"Sensor-B20-M0"
21	"Sensor-B1412-M2"
22	"Sensor-B14-M1"
23	"Sensor-B596-M0"
...
*/

-- 8. Ranking de zonas monitoreadas (Uso de DENSE_RANK)
SELECT 
    u.nombre_zona, 
    COUNT(DISTINCT e.building_id) AS edificios_monitoreados,
    DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT e.building_id) DESC) as posicion_ranking
FROM ubicacion u
JOIN edificio e ON u.id_ubicacion = e.id_ubicacion
GROUP BY u.nombre_zona;

/* Resultados de prueba:
"nombre_zona"	"edificios_monitoreados"	"posicion_ranking"
"Zona 3"	274	1
"Zona 13"	154	2
"Zona 2"	135	3
"Zona 9"	124	4
"Zona 15"	124	4
"Zona 0"	105	5
"Zona 14"	102	6
"Zona 4"	91	7
"Zona 5"	89	8
"Zona 8"	70	9
"Zona 1"	51	10
"Zona 6"	44	11
"Zona 12"	36	12
"Zona 10"	30	13
"Zona 7"	15	14
"Zona 11"	5	15
*/

-- 9. Consulta utilizando la vista creada por la Persona 1
SELECT nombre_zona, nombre_categoria, cantidad_sensores 
FROM vw_resumen_sensores_zona 
WHERE sensores_activos > 0 
ORDER BY cantidad_sensores DESC;

/* Resultados de prueba:
"nombre_zona"	"nombre_categoria"	"cantidad_sensores"
"Zona 3"	"Electricidad"	274
"Zona 13"	"Electricidad"	141
"Zona 2"	"Electricidad"	135
"Zona 9"	"Electricidad"	122
"Zona 15"	"Electricidad"	114
"Zona 0"	"Electricidad"	105
"Zona 14"	"Electricidad"	102
"Zona 2"	"Agua fría"	99
"Zona 9"	"Agua fría"	95
"Zona 4"	"Electricidad"	91
"Zona 9"	"Vapor"	89
"Zona 5"	"Electricidad"	89
"Zona 13"	"Vapor"	88
"Zona 14"	"Agua fría"	86
"Zona 13"	"Agua fría"	80
"Zona 8"	"Electricidad"	70
"Zona 15"	"Vapor"	69
"Zona 15"	"Agua fría"	65
"Zona 14"	"Agua caliente"	57
"Zona 2"	"Agua caliente"	55
"Zona 1"	"Electricidad"	51
"Zona 14"	"Vapor"	43
"Zona 12"	"Electricidad"	36
"Zona 6"	"Electricidad"	36
"Zona 10"	"Electricidad"	30
"Zona 0"	"Agua fría"	24
"Zona 6"	"Vapor"	23
"Zona 6"	"Agua fría"	21
"Zona 7"	"Agua fría"	15
"Zona 7"	"Vapor"	12
"Zona 1"	"Agua caliente"	12
"Zona 7"	"Electricidad"	12
"Zona 10"	"Agua caliente"	11
"Zona 10"	"Agua fría"	9
"Zona 11"	"Electricidad"	5
"Zona 11"	"Agua caliente"	5
"Zona 11"	"Agua fría"	4
"Zona 7"	"Agua caliente"	3
"Zona 15"	"Agua caliente"	2
*/

-- 10. Consulta utilizando el procedimiento almacenado / función (Estadísticas del sensor 1)
-- Evaluamos estadísticas en un rango de fechas utilizando la función de la Persona 1
SELECT * 
FROM fn_estadisticas_sensor_periodo(
    1, 
    '2015-01-01 00:00:00'::TIMESTAMP, 
    '2017-12-31 00:00:00'::TIMESTAMP
);

/* Resultados de prueba:
"id_sensor"	"desde"	"hasta"	"cantidad_lecturas"	"valor_minimo"	"valor_maximo"	"valor_promedio"	"valor_total"
1	"2015-01-01 00:00:00"	"2017-12-31 00:00:00"	8765	0.000000	539.000000	145.4552196235025670	1274915.000000
*/