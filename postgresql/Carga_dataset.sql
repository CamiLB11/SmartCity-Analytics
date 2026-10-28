-- Ejecución de carga del dataset
SET search_path TO smartcity, public;

SELECT COUNT(*) AS filas_staging
FROM stg_energia;

SELECT *
FROM stg_energia
LIMIT 20;

SELECT
    COUNT(*) FILTER (WHERE building_id IS NULL) AS sin_edificio,
    COUNT(*) FILTER (WHERE site_id IS NULL) AS sin_ubicacion,
    COUNT(*) FILTER (WHERE meter IS NULL) AS sin_medidor,
    COUNT(*) FILTER (WHERE unixtimestamp IS NULL) AS sin_fecha,
    COUNT(*) FILTER (WHERE meter_reading < 0) AS lecturas_negativas
FROM stg_energia;

CALL sp_procesar_staging_energia();

CALL sp_finalizar_carga();

SELECT 'ubicacion' AS tabla, COUNT(*) AS filas FROM ubicacion
UNION ALL SELECT 'tipo_uso_edificio', COUNT(*) FROM tipo_uso_edificio
UNION ALL SELECT 'edificio', COUNT(*) FROM edificio
UNION ALL SELECT 'sensor', COUNT(*) FROM sensor
UNION ALL SELECT 'observacion_climatica', COUNT(*) FROM observacion_climatica
UNION ALL SELECT 'lectura_sensor', COUNT(*) FROM lectura_sensor
ORDER BY tabla;

SELECT *
FROM vw_detalle_sensor
ORDER BY id_sensor
LIMIT 25;
