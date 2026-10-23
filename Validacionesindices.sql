-- Validación de datos, relaciones e índices
SET search_path TO smartcity, public;

SELECT 'ubicacion' AS tabla, COUNT(*) AS filas FROM ubicacion
UNION ALL SELECT 'tipo_uso_edificio', COUNT(*) FROM tipo_uso_edificio
UNION ALL SELECT 'edificio', COUNT(*) FROM edificio
UNION ALL SELECT 'sensor', COUNT(*) FROM sensor
UNION ALL SELECT 'lectura_sensor', COUNT(*) FROM lectura_sensor
UNION ALL SELECT 'observacion_climatica', COUNT(*) FROM observacion_climatica
UNION ALL SELECT 'stg_energia', COUNT(*) FROM stg_energia
ORDER BY tabla;

-- sensores sin lecturas
SELECT s.id_sensor, s.nombre
FROM sensor s
WHERE NOT EXISTS (
    SELECT 1 FROM lectura_sensor l
    WHERE l.id_sensor = s.id_sensor
);

-- edificios sin ubicación válida
SELECT e.building_id, e.id_ubicacion
FROM edificio e
LEFT JOIN ubicacion u ON u.id_ubicacion = e.id_ubicacion
WHERE u.id_ubicacion IS NULL;

-- edificios sin tipo de uso válido
SELECT e.building_id, e.id_uso
FROM edificio e
LEFT JOIN tipo_uso_edificio t ON t.id_uso = e.id_uso
WHERE t.id_uso IS NULL;

-- sensores sin edificio válido
SELECT s.id_sensor, s.building_id
FROM sensor s
LEFT JOIN edificio e ON e.building_id = s.building_id
WHERE e.building_id IS NULL;

-- lecturas sin sensor válido
SELECT l.id_sensor, l.fecha_hora
FROM lectura_sensor l
LEFT JOIN sensor s ON s.id_sensor = l.id_sensor
WHERE s.id_sensor IS NULL
LIMIT 100;

-- duplicados
SELECT building_id, meter, unixtimestamp, COUNT(*) AS repeticiones
FROM stg_energia
WHERE building_id IS NOT NULL
  AND meter IS NOT NULL
  AND unixtimestamp IS NOT NULL
GROUP BY building_id, meter, unixtimestamp
HAVING COUNT(*) > 1
ORDER BY repeticiones DESC
LIMIT 100;

-- distribución de estados
SELECT estado, COUNT(*) AS cantidad
FROM sensor
GROUP BY estado
ORDER BY estado;

SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'smartcity'
ORDER BY tablename, indexname;

-- restricciones 
SELECT table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'smartcity'
ORDER BY table_name, constraint_type, constraint_name;

SELECT relname AS tabla,
       pg_size_pretty(pg_total_relation_size(relid)) AS tamano_total,
       pg_size_pretty(pg_indexes_size(relid)) AS tamano_indices
FROM pg_catalog.pg_statio_user_tables
WHERE schemaname = 'smartcity'
ORDER BY pg_total_relation_size(relid) DESC;

ANALYZE ubicacion;
ANALYZE tipo_uso_edificio;
ANALYZE edificio;
ANALYZE sensor;
ANALYZE observacion_climatica;
ANALYZE lectura_sensor;

SELECT COUNT(*) AS sensores_con_ultima_lectura
FROM mv_ultima_lectura_sensor;

