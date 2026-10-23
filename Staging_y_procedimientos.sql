SET search_path TO smartcity, public;

DROP TABLE IF EXISTS stg_energia;
CREATE UNLOGGED TABLE stg_energia (
    building_id         INTEGER,
    meter               SMALLINT,
    meter_reading       NUMERIC(20,6),
    site_id             SMALLINT,
    primary_use         VARCHAR(120),
    square_feet         NUMERIC(14,2),
    year_built          NUMERIC(8,2),
    floor_count         NUMERIC(8,2),
    air_temperature     NUMERIC(10,4),
    cloud_coverage      NUMERIC(10,4),
    dew_temperature     NUMERIC(10,4),
    precip_depth_1_hr   NUMERIC(14,4),
    sea_level_pressure  NUMERIC(12,4),
    wind_direction      NUMERIC(10,4),
    wind_speed          NUMERIC(10,4),
    unixtimestamp       BIGINT
);

CREATE OR REPLACE PROCEDURE sp_procesar_staging_energia()
LANGUAGE plpgsql
AS $$
DECLARE
    v_org INTEGER;
BEGIN
    SELECT id_organismo
      INTO v_org
      FROM organismo_responsable
     WHERE nombre = 'Unidad de Gestión Energética SmartCity';

    --site_id identificador real del dataset
    INSERT INTO ubicacion (id_ubicacion, nombre_zona)
    SELECT DISTINCT
           site_id,
           'Sitio ' || site_id::TEXT
    FROM stg_energia
    WHERE site_id IS NOT NULL
    ON CONFLICT (id_ubicacion) DO NOTHING;

    -- Catalogo usos primarios
    INSERT INTO tipo_uso_edificio (nombre_uso)
    SELECT DISTINCT TRIM(primary_use)
    FROM stg_energia
    WHERE primary_use IS NOT NULL
      AND TRIM(primary_use) <> ''
    ON CONFLICT (nombre_uso) DO NOTHING;

    -- registro por building_id
    INSERT INTO edificio (
        building_id, id_ubicacion, id_uso,
        square_feet, year_built, floor_count
    )
    SELECT
        x.building_id,
        x.site_id,
        tu.id_uso,
        x.square_feet,
        x.year_built,
        x.floor_count
    FROM (
        SELECT
            building_id,
            MIN(site_id) AS site_id,
            MIN(TRIM(primary_use)) AS primary_use,
            MAX(square_feet) AS square_feet,
            ROUND(MAX(year_built))::SMALLINT AS year_built,
            ROUND(MAX(floor_count))::SMALLINT AS floor_count
        FROM stg_energia
        WHERE building_id IS NOT NULL
        GROUP BY building_id
    ) x
    JOIN tipo_uso_edificio tu ON tu.nombre_uso = x.primary_use
    ON CONFLICT (building_id) DO UPDATE
    SET id_ubicacion = EXCLUDED.id_ubicacion,
        id_uso       = EXCLUDED.id_uso,
        square_feet  = EXCLUDED.square_feet,
        year_built   = COALESCE(edificio.year_built, EXCLUDED.year_built),
        floor_count  = COALESCE(edificio.floor_count, EXCLUDED.floor_count);

    -- Sensor: edificio + tipo de medidor
    -- fecha_instalacion: fecha de primera lectura disponible
    INSERT INTO sensor (
        building_id, id_categoria, id_organismo,
        nombre, fecha_instalacion, estado
    )
    SELECT
        s.building_id,
        c.id_categoria,
        v_org,
        'MTR-B' || s.building_id::TEXT || '-T' || s.meter::TEXT,
        (TO_TIMESTAMP(MIN(s.unixtimestamp)) AT TIME ZONE 'UTC')::DATE,
        'ACTIVO'
    FROM stg_energia s
    JOIN categoria_sensor c ON c.codigo_meter = s.meter
    WHERE s.building_id IS NOT NULL
      AND s.meter IS NOT NULL
      AND s.unixtimestamp IS NOT NULL
    GROUP BY s.building_id, s.meter, c.id_categoria
    ON CONFLICT (building_id, id_categoria) DO UPDATE
    SET fecha_instalacion = LEAST(sensor.fecha_instalacion, EXCLUDED.fecha_instalacion),
        id_organismo = COALESCE(sensor.id_organismo, EXCLUDED.id_organismo);

   
    INSERT INTO observacion_climatica (
        id_ubicacion, fecha_hora,
        air_temperature, cloud_coverage, dew_temperature,
        precip_depth_1_hr, sea_level_pressure,
        wind_direction, wind_speed
    )
    SELECT
        site_id,
        TO_TIMESTAMP(unixtimestamp) AT TIME ZONE 'UTC',
        MAX(air_temperature),
        MAX(cloud_coverage),
        MAX(dew_temperature),
        MAX(precip_depth_1_hr),
        MAX(sea_level_pressure),
        MAX(wind_direction),
        MAX(wind_speed)
    FROM stg_energia
    WHERE site_id IS NOT NULL
      AND unixtimestamp IS NOT NULL
    GROUP BY site_id, unixtimestamp
    ON CONFLICT (id_ubicacion, fecha_hora) DO UPDATE
    SET air_temperature    = COALESCE(observacion_climatica.air_temperature, EXCLUDED.air_temperature),
        cloud_coverage     = COALESCE(observacion_climatica.cloud_coverage, EXCLUDED.cloud_coverage),
        dew_temperature    = COALESCE(observacion_climatica.dew_temperature, EXCLUDED.dew_temperature),
        precip_depth_1_hr  = COALESCE(observacion_climatica.precip_depth_1_hr, EXCLUDED.precip_depth_1_hr),
        sea_level_pressure = COALESCE(observacion_climatica.sea_level_pressure, EXCLUDED.sea_level_pressure),
        wind_direction     = COALESCE(observacion_climatica.wind_direction, EXCLUDED.wind_direction),
        wind_speed         = COALESCE(observacion_climatica.wind_speed, EXCLUDED.wind_speed);

    -- Lecturas de consumo
	INSERT INTO lectura_sensor (id_sensor, fecha_hora, valor)
    SELECT
        sn.id_sensor,
        TO_TIMESTAMP(s.unixtimestamp) AT TIME ZONE 'UTC',
        s.meter_reading
    FROM stg_energia s
    JOIN categoria_sensor c
      ON c.codigo_meter = s.meter
    JOIN sensor sn
      ON sn.building_id = s.building_id
     AND sn.id_categoria = c.id_categoria
    WHERE s.meter_reading IS NOT NULL
      AND s.meter_reading >= 0
      AND s.unixtimestamp IS NOT NULL
    ON CONFLICT (id_sensor, fecha_hora) DO NOTHING;

    ANALYZE ubicacion;
    ANALYZE tipo_uso_edificio;
    ANALYZE edificio;
    ANALYZE sensor;
    ANALYZE observacion_climatica;
    ANALYZE lectura_sensor;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_finalizar_carga()
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_fecha TIMESTAMP;
BEGIN
    REFRESH MATERIALIZED VIEW mv_ultima_lectura_sensor;

    SELECT MAX(ultima_lectura)
      INTO v_max_fecha
      FROM mv_ultima_lectura_sensor;

    -- ACTIVO = tuvo lectura dentro de las 24 h finales del dataset
    UPDATE sensor s
       SET estado = CASE
           WHEN m.ultima_lectura >= v_max_fecha - INTERVAL '24 hours'
               THEN 'ACTIVO'
           ELSE 'INACTIVO'
       END
      FROM mv_ultima_lectura_sensor m
     WHERE m.id_sensor = s.id_sensor;

    -- Sensores sin ninguna lectura se consideran inactivos
    UPDATE sensor s
       SET estado = 'INACTIVO'
     WHERE NOT EXISTS (
         SELECT 1
           FROM mv_ultima_lectura_sensor m
          WHERE m.id_sensor = s.id_sensor
     );

    ANALYZE sensor;
END;
$$;
