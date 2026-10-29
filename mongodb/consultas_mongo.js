use smartcity_analytics;

// --- Operaciones CRUD ---

// Probando insertOne con una alerta de inspección manual
db.alerts.insertOne({
    alert_type: "MANUAL_INSPECTION",
    severity: "MEDIUM",
    status: "OPEN",
    timestamp: new Date(),
    sensor_id: "MTR-B46-T0",
    building_id: 46,
    site_id: 0,
    message: "Revisión programada por anomalía térmica",
    source: "dashboard_manual"
});

// Insertando un par de eventos de falla con insertMany
db.sensor_events.insertMany([
    {
        sensor_id: "MTR-B10-T1",
        building_id: 10,
        site_id: 1,
        event_type: "CONNECTION_LOST",
        timestamp: new Date(),
        description: "Pérdida de señal con el gateway principal",
        source: "system_monitor"
    },
    {
        sensor_id: "MTR-B12-T1",
        building_id: 12,
        site_id: 1,
        event_type: "BATTERY_LOW",
        timestamp: new Date(),
        description: "Batería por debajo del 15%",
        source: "system_monitor"
    }
]);

// Buscando cualquier lectura del edificio 46 (findOne)
db.sensor_readings.findOne({ building_id: 46 });

// Sacando todas las alertas que siguen abiertas (find)
db.alerts.find({ status: "OPEN" });

// Cambiando el estado de una alerta a "en progreso" (updateOne)
db.alerts.updateOne(
    { sensor_id: "MTR-B46-T0", status: "OPEN" },
    { $set: { status: "IN_PROGRESS" } }
);

// Actualizando varios eventos de conexión perdida para pedir técnico (updateMany)
db.sensor_events.updateMany(
    { event_type: "CONNECTION_LOST" },
    { $set: { metadata: { requires_technician: true } } }
);

// Borrando el evento de prueba que venía del script de carga inicial (deleteOne)
db.sensor_events.deleteOne({ _id: "demo-event-001" });


// --- 10 Consultas Obligatorias ---

// 1. Últimas 10 lecturas del sensor del edificio 46
db.sensor_readings.find(
    { sensor_id: "MTR-B46-T0" }
).sort({ timestamp: -1 }).limit(10);

// 2. Lecturas del mes de enero de 2016 (fechas originales del dataset)
db.sensor_readings.find({
    timestamp: {
        $gte: ISODate("2016-01-01T00:00:00Z"),
        $lte: ISODate("2016-01-31T23:59:59Z")
    }
}).limit(10);

// 3. Valores máximos y mínimos registrados por cada sitio (site_id)
db.sensor_readings.aggregate([
    {
        $group: {
            _id: "$site_id",
            lecturaMaxima: { $max: "$value" },
            lecturaMinima: { $min: "$value" }
        }
    }
]);

// 4. Filtrando alertas graves
db.alerts.find({ severity: "CRITICAL" });

// 5. Contando cuántas alertas activas hay por zona
db.alerts.aggregate([
    { $match: { status: { $ne: "RESOLVED" } } },
    { $group: { _id: "$site_id", totalAlertasActivas: { $sum: 1 } } },
    { $sort: { totalAlertasActivas: -1 } }
]);

// 6. Promedio general de lecturas por zona
db.sensor_readings.aggregate([
    {
        $group: {
            _id: "$site_id",
            promedioLecturas: { $avg: "$value" }
        }
    },
    { $sort: { promedioLecturas: -1 } }
]);

// 7. Promedio de lecturas según el tipo de medidor (redondeado a 2 decimales)
db.sensor_readings.aggregate([
    {
        $group: {
            _id: "$meter",
            promedioLecturas: { $avg: "$value" }
        }
    },
    {
        $project: {
            _id: 1,
            promedioLecturas: { $round: ["$promedioLecturas", 2] }
        }
    }
]);

// 8. Contando el número de incidentes agrupados por tipo
db.sensor_events.aggregate([
    { $group: { _id: "$event_type", cantidadIncidentes: { $sum: 1 } } },
    { $sort: { cantidadIncidentes: -1 } }
]);

// 9. Top 5 de edificios comerciales con mayor temperatura promedio
db.sensor_readings.aggregate([
    { $match: { primary_use: "Retail", air_temperature: { $ne: null } } },
    { $group: { _id: "$building_id", tempAirePromedio: { $avg: "$air_temperature" } } },
    { $sort: { tempAirePromedio: -1 } },
    { $limit: 5 },
    { $project: { edificio: "$_id", tempAirePromedio: { $round: ["$tempAirePromedio", 1] }, _id: 0 } }
]);

// 10. Buscando lecturas altas de medidores eléctricos en edificios grandes (limitando campos de salida)
db.sensor_readings.find(
    {
        meter: 0,
        square_feet: { $gt: 50000 },
        value: { $gt: 500 }
    },
    {
        _id: 0,
        sensor_id: 1,
        building_id: 1,
        value: 1,
        timestamp: 1
    }
).sort({ value: -1 }).limit(10);