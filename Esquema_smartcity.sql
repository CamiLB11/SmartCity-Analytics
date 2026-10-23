BEGIN;

DROP SCHEMA IF EXISTS smartcity CASCADE;
CREATE SCHEMA smartcity;
SET search_path TO smartcity, public;

-- Tipos de uso del edificio
CREATE TABLE tipo_uso_edificio (
    id_uso              SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_uso          VARCHAR(120) NOT NULL UNIQUE
);

-- Ubicaciones
CREATE TABLE ubicacion (
    id_ubicacion        SMALLINT PRIMARY KEY,
    nombre_zona         VARCHAR(120) NOT NULL,
    distrito            VARCHAR(120),
    coordenadas         POINT,
    CONSTRAINT uq_ubicacion_nombre UNIQUE (nombre_zona)
);

--Categorías de sensor/medidor
CREATE TABLE categoria_sensor (
    id_categoria        SMALLINT PRIMARY KEY,
    codigo_meter        SMALLINT NOT NULL UNIQUE,
    nombre_categoria    VARCHAR(80) NOT NULL UNIQUE,
    descripcion         VARCHAR(250),
    CONSTRAINT ck_categoria_meter CHECK (codigo_meter BETWEEN 0 AND 3)
);

-- Organismos responsables
CREATE TABLE organismo_responsable (
    id_organismo        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre              VARCHAR(150) NOT NULL UNIQUE,
    responsable         VARCHAR(150)
);

-- Usuarios del sistema
CREATE TABLE usuario_sistema (
    id_usuario          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre              VARCHAR(150) NOT NULL,
    correo              VARCHAR(254) NOT NULL UNIQUE,
    fecha_creacion      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Edificios
CREATE TABLE edificio (
    building_id         INTEGER PRIMARY KEY,
    id_ubicacion        SMALLINT NOT NULL,
    id_uso              SMALLINT NOT NULL,
    square_feet         NUMERIC(14,2) NOT NULL,
    year_built          SMALLINT,
    floor_count         SMALLINT,
    CONSTRAINT fk_edificio_ubicacion
        FOREIGN KEY (id_ubicacion) REFERENCES ubicacion(id_ubicacion),
    CONSTRAINT fk_edificio_uso
        FOREIGN KEY (id_uso) REFERENCES tipo_uso_edificio(id_uso),
    CONSTRAINT ck_edificio_square_feet CHECK (square_feet > 0),
    CONSTRAINT ck_edificio_year CHECK (year_built IS NULL OR year_built BETWEEN 1700 AND 2100),
    CONSTRAINT ck_edificio_floor CHECK (floor_count IS NULL OR floor_count > 0)
);

--Sensor/medidor

CREATE TABLE sensor (
    id_sensor           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    building_id         INTEGER NOT NULL,
    id_categoria        SMALLINT NOT NULL,
    id_organismo        INTEGER,
    nombre              VARCHAR(140) NOT NULL,
    fecha_instalacion   DATE,
    estado              VARCHAR(10) NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT fk_sensor_edificio
        FOREIGN KEY (building_id) REFERENCES edificio(building_id),
    CONSTRAINT fk_sensor_categoria
        FOREIGN KEY (id_categoria) REFERENCES categoria_sensor(id_categoria),
    CONSTRAINT fk_sensor_organismo
        FOREIGN KEY (id_organismo) REFERENCES organismo_responsable(id_organismo),
    CONSTRAINT uq_sensor_edificio_categoria UNIQUE (building_id, id_categoria),
    CONSTRAINT uq_sensor_nombre UNIQUE (nombre),
    CONSTRAINT ck_sensor_estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);

-- Observaciones meteorológicas
CREATE TABLE observacion_climatica (
    id_ubicacion            SMALLINT NOT NULL,
    fecha_hora              TIMESTAMP NOT NULL,
    air_temperature         NUMERIC(7,3),
    cloud_coverage          NUMERIC(7,3),
    dew_temperature         NUMERIC(7,3),
    precip_depth_1_hr       NUMERIC(12,4),
    sea_level_pressure      NUMERIC(10,3),
    wind_direction          NUMERIC(7,3),
    wind_speed              NUMERIC(8,3),
    PRIMARY KEY (id_ubicacion, fecha_hora),
    CONSTRAINT fk_clima_ubicacion
        FOREIGN KEY (id_ubicacion) REFERENCES ubicacion(id_ubicacion),
    CONSTRAINT ck_wind_direction CHECK (
        wind_direction IS NULL OR (wind_direction >= 0 AND wind_direction <= 360)
    ),
    CONSTRAINT ck_wind_speed CHECK (wind_speed IS NULL OR wind_speed >= 0)
);

--Lecturas
CREATE TABLE lectura_sensor (
    id_sensor           BIGINT NOT NULL,
    fecha_hora          TIMESTAMP NOT NULL,
    valor               NUMERIC(20,6) NOT NULL,
    PRIMARY KEY (id_sensor, fecha_hora),
    CONSTRAINT fk_lectura_sensor
        FOREIGN KEY (id_sensor) REFERENCES sensor(id_sensor),
    CONSTRAINT ck_lectura_valor CHECK (valor >= 0)
);

--- Indices
CREATE INDEX idx_edificio_ubicacion ON edificio(id_ubicacion);
CREATE INDEX idx_edificio_uso       ON edificio(id_uso);
CREATE INDEX idx_sensor_categoria   ON sensor(id_categoria);
CREATE INDEX idx_sensor_organismo   ON sensor(id_organismo);
CREATE INDEX idx_sensor_estado      ON sensor(estado);

CREATE INDEX idx_lectura_fecha_brin
    ON lectura_sensor USING BRIN (fecha_hora) WITH (pages_per_range = 128);
CREATE INDEX idx_clima_fecha_brin
    ON observacion_climatica USING BRIN (fecha_hora) WITH (pages_per_range = 128);


INSERT INTO categoria_sensor (id_categoria, codigo_meter, nombre_categoria, descripcion)
VALUES
    (1, 0, 'Electricidad', 'Medidor tipo 0'),
    (2, 1, 'Agua fría',    'Medidor tipo 1'),
    (3, 2, 'Vapor',        'Medidor tipo 2'),
    (4, 3, 'Agua caliente','Medidor tipo 3')
ON CONFLICT (id_categoria) DO NOTHING;

INSERT INTO organismo_responsable (nombre, responsable)
VALUES ('Unidad de Gestión Energética SmartCity', 'Equipo SmartCity')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO usuario_sistema (nombre, correo)
VALUES ('Administrador SmartCity', 'admin@smartcity.local')
ON CONFLICT (correo) DO NOTHING;

-- Consultas
CREATE VIEW vw_resumen_sensores_zona AS
SELECT
    u.id_ubicacion,
    u.nombre_zona,
    c.id_categoria,
    c.nombre_categoria,
    COUNT(*) AS cantidad_sensores,
    COUNT(*) FILTER (WHERE s.estado = 'ACTIVO') AS sensores_activos,
    COUNT(*) FILTER (WHERE s.estado = 'INACTIVO') AS sensores_inactivos
FROM sensor s
JOIN edificio e          ON e.building_id = s.building_id
JOIN ubicacion u         ON u.id_ubicacion = e.id_ubicacion
JOIN categoria_sensor c  ON c.id_categoria = s.id_categoria
GROUP BY u.id_ubicacion, u.nombre_zona, c.id_categoria, c.nombre_categoria;

CREATE VIEW vw_detalle_sensor AS
SELECT
    s.id_sensor,
    s.nombre AS sensor,
    s.estado,
    s.fecha_instalacion,
    c.nombre_categoria,
    e.building_id,
    u.id_ubicacion,
    u.nombre_zona,
    tu.nombre_uso,
    o.nombre AS organismo
FROM sensor s
JOIN categoria_sensor c       ON c.id_categoria = s.id_categoria
JOIN edificio e               ON e.building_id = s.building_id
JOIN ubicacion u              ON u.id_ubicacion = e.id_ubicacion
JOIN tipo_uso_edificio tu     ON tu.id_uso = e.id_uso
LEFT JOIN organismo_responsable o ON o.id_organismo = s.id_organismo;

CREATE MATERIALIZED VIEW mv_ultima_lectura_sensor AS
SELECT
    id_sensor,
    MAX(fecha_hora) AS ultima_lectura
FROM lectura_sensor
GROUP BY id_sensor
WITH NO DATA;

CREATE UNIQUE INDEX idx_mv_ultima_lectura_sensor
    ON mv_ultima_lectura_sensor(id_sensor);


CREATE OR REPLACE FUNCTION fn_estadisticas_sensor_periodo(
    p_id_sensor BIGINT,
    p_desde TIMESTAMP,
    p_hasta TIMESTAMP
)
RETURNS TABLE (
    id_sensor BIGINT,
    desde TIMESTAMP,
    hasta TIMESTAMP,
    cantidad_lecturas BIGINT,
    valor_minimo NUMERIC,
    valor_maximo NUMERIC,
    valor_promedio NUMERIC,
    valor_total NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        p_id_sensor,
        p_desde,
        p_hasta,
        COUNT(*)::BIGINT,
        MIN(l.valor),
        MAX(l.valor),
        AVG(l.valor),
        SUM(l.valor)
    FROM lectura_sensor l
    WHERE l.id_sensor = p_id_sensor
      AND l.fecha_hora >= p_desde
      AND l.fecha_hora < p_hasta;
$$;

COMMIT;
