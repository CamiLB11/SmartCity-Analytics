/*
 * SmartCity Analytics
 * Modelo documental y carga del conjunto de datos en MongoDB.
 *
 * Requisitos: Node.js, MongoDB en ejecucion y paquetes mongodb/csv-parse.
 * Los archivos trainM0.csv, trainM1.csv, trainM2.csv y trainM3.csv
 * deben estar en la carpeta data/.
 *
 * Ejecucion: node mongodb_modelo.js
 */

"use strict";

const fs = require("fs");
const path = require("path");
const { MongoClient } = require("mongodb");
const { parse } = require("csv-parse");

const MONGO_URI =
  process.env.MONGODB_URI || "mongodb://127.0.0.1:27017";

const DATABASE_NAME = "smartcity_analytics";

const DATA_DIRECTORY =
  process.env.DATA_DIRECTORY || path.join(__dirname, "data");

const MAX_ROWS_PER_FILE = Number.parseInt(
  process.env.MAX_ROWS_PER_FILE || "0",
  10
);

const CSV_FILES = [
  "trainM0.csv",
  "trainM1.csv",
  "trainM2.csv",
  "trainM3.csv"
];

const BATCH_SIZE = 2000;

const NUMERIC_FIELDS = new Set([
  "building_id",
  "meter",
  "meter_reading",
  "site_id",
  "square_feet",
  "year_built",
  "floor_count",
  "air_temperature",
  "cloud_coverage",
  "dew_temperature",
  "precip_depth_1_hr",
  "sea_level_pressure",
  "wind_direction",
  "wind_speed",
  "unixtimestamp"
]);

const INTEGER_FIELDS = new Set([
  "building_id",
  "meter",
  "site_id",
  "unixtimestamp"
]);

const NUMERIC_BSON_TYPES = ["double", "int", "long", "decimal"];

const VALIDATORS = {
  sensor_readings: {
    $jsonSchema: {
      bsonType: "object",
      required: [
        "sensor_id",
        "building_id",
        "site_id",
        "meter",
        "meter_reading",
        "value",
        "unixtimestamp",
        "timestamp",
        "source",
        "source_file"
      ],
      properties: {
        _id: {
          bsonType: ["string", "objectId"]
        },
        sensor_id: {
          bsonType: "string"
        },
        building_id: {
          bsonType: NUMERIC_BSON_TYPES
        },
        site_id: {
          bsonType: NUMERIC_BSON_TYPES
        },
        meter: {
          bsonType: NUMERIC_BSON_TYPES,
          minimum: 0,
          maximum: 3
        },
        meter_reading: {
          bsonType: NUMERIC_BSON_TYPES
        },
        value: {
          bsonType: NUMERIC_BSON_TYPES
        },
        unixtimestamp: {
          bsonType: NUMERIC_BSON_TYPES
        },
        timestamp: {
          bsonType: "date"
        },
        source: {
          bsonType: "string"
        },
        source_file: {
          bsonType: "string"
        },
        primary_use: {
          bsonType: ["string", "null"]
        },
        square_feet: {
          bsonType: [...NUMERIC_BSON_TYPES, "null"]
        },
        year_built: {
          bsonType: [...NUMERIC_BSON_TYPES, "null"]
        },
        floor_count: {
          bsonType: [...NUMERIC_BSON_TYPES, "null"]
        },
        air_temperature: {
          bsonType: [...NUMERIC_BSON_TYPES, "null"]
        },
        cloud_coverage: {
          bsonType: [...NUMERIC_BSON_TYPES, "null"]
        },
        dew_temperature: {
          bsonType: [...NUMERIC_BSON_TYPES, "null"]
        },
        precip_depth_1_hr: {
          bsonType: [...NUMERIC_BSON_TYPES, "null"]
        },
        sea_level_pressure: {
          bsonType: [...NUMERIC_BSON_TYPES, "null"]
        },
        wind_direction: {
          bsonType: [...NUMERIC_BSON_TYPES, "null"]
        },
        wind_speed: {
          bsonType: [...NUMERIC_BSON_TYPES, "null"]
        }
      }
    }
  },

  sensor_events: {
    $jsonSchema: {
      bsonType: "object",
      required: [
        "sensor_id",
        "building_id",
        "site_id",
        "event_type",
        "timestamp",
        "description",
        "source"
      ],
      properties: {
        _id: {
          bsonType: ["string", "objectId"]
        },
        sensor_id: {
          bsonType: "string"
        },
        building_id: {
          bsonType: NUMERIC_BSON_TYPES
        },
        site_id: {
          bsonType: NUMERIC_BSON_TYPES
        },
        event_type: {
          enum: [
            "INSTALLATION",
            "MAINTENANCE",
            "CALIBRATION",
            "STATUS_CHANGE",
            "BATTERY_LOW",
            "CONNECTION_LOST",
            "CONNECTION_RESTORED"
          ]
        },
        timestamp: {
          bsonType: "date"
        },
        description: {
          bsonType: "string"
        },
        previous_status: {
          bsonType: "string"
        },
        new_status: {
          bsonType: "string"
        },
        source: {
          bsonType: "string"
        },
        metadata: {
          bsonType: "object"
        }
      }
    }
  },

  alerts: {
    $jsonSchema: {
      bsonType: "object",
      required: [
        "alert_type",
        "severity",
        "status",
        "timestamp",
        "sensor_id",
        "building_id",
        "site_id",
        "message",
        "source"
      ],
      properties: {
        _id: {
          bsonType: ["string", "objectId"]
        },
        alert_type: {
          bsonType: "string"
        },
        severity: {
          enum: ["LOW", "MEDIUM", "HIGH", "CRITICAL"]
        },
        status: {
          enum: [
            "OPEN",
            "IN_PROGRESS",
            "ACKNOWLEDGED",
            "RESOLVED"
          ]
        },
        timestamp: {
          bsonType: "date"
        },
        sensor_id: {
          bsonType: "string"
        },
        building_id: {
          bsonType: NUMERIC_BSON_TYPES
        },
        site_id: {
          bsonType: NUMERIC_BSON_TYPES
        },
        message: {
          bsonType: "string"
        },
        source: {
          bsonType: "string"
        },
        related_reading_timestamp: {
          bsonType: "date"
        },
        threshold: {
          bsonType: NUMERIC_BSON_TYPES
        },
        observed_value: {
          bsonType: NUMERIC_BSON_TYPES
        },
        metadata: {
          bsonType: "object"
        }
      }
    }
  }
};

function convertValue(field, rawValue) {
  if (rawValue === undefined || rawValue === null) {
    return null;
  }

  const value = String(rawValue).trim();

  if (value === "") {
    return null;
  }

  if (!NUMERIC_FIELDS.has(field)) {
    return value;
  }

  const number = Number(value);

  if (!Number.isFinite(number)) {
    return null;
  }

  if (
    INTEGER_FIELDS.has(field) &&
    !Number.isInteger(number)
  ) {
    throw new Error(
      `Se esperaba un entero para ${field}: ${value}`
    );
  }

  return number;
}

function transformRow(row, fileName) {
  const document = {};

  for (const [field, rawValue] of Object.entries(row)) {
    document[field] = convertValue(field, rawValue);
  }

  const requiredFields = [
    "building_id",
    "meter",
    "site_id",
    "unixtimestamp",
    "meter_reading"
  ];

  for (const field of requiredFields) {
    if (
      document[field] === null ||
      document[field] === undefined
    ) {
      throw new Error(
        `Campo requerido vacio (${field}) en ${fileName}: ` +
        JSON.stringify(row)
      );
    }
  }

  if (document.meter < 0 || document.meter > 3) {
    throw new Error(
      `Tipo de medidor fuera del rango 0-3 en ${fileName}: ` +
      document.meter
    );
  }

  const timestampSeconds = document.unixtimestamp;

  document.timestamp = new Date(timestampSeconds * 1000);

  if (Number.isNaN(document.timestamp.getTime())) {
    throw new Error(
      `Timestamp invalido en ${fileName}: ${timestampSeconds}`
    );
  }

  /*
   * Los CSV no contienen sensor_id.
   * Se define una convencion estable a partir del edificio
   * y el tipo de medidor.
   */
  document.sensor_id =
    `MTR-B${document.building_id}-T${document.meter}`;

  /*
   * Se conserva meter_reading y se agrega value como alias.
   */
  document.value = document.meter_reading;

  document.source = fileName;
  document.source_file = fileName;

  /*
   * Identificador estable por edificio, medidor y timestamp.
   */
  document._id = [
    document.building_id,
    document.meter,
    timestampSeconds
  ].join("_");

  return document;
}

async function ensureCollections(db) {
  const existing = new Set(
    (
      await db
        .listCollections({}, { nameOnly: true })
        .toArray()
    ).map((collection) => collection.name)
  );

  for (const [name, validator] of Object.entries(VALIDATORS)) {
    if (!existing.has(name)) {
      await db.createCollection(name, {
        validator,
        validationLevel: "strict",
        validationAction: "error"
      });

      console.log(`Coleccion creada: ${name}`);
    } else {
      await db.command({
        collMod: name,
        validator,
        validationLevel: "strict",
        validationAction: "error"
      });

      console.log(`Coleccion existente preparada: ${name}`);
    }
  }
}

async function removeOldDemoRecords(db) {
  /*
   * Elimina solo los documentos de ejemplo creados por
   * la version anterior del script.
   */
  await db.collection("sensor_readings").deleteMany({
    _id: {
      $in: [
        "demo-reading-001",
        "demo-reading-002",
        "demo-reading-003"
      ]
    }
  });

  await db.collection("sensor_events").deleteMany({
    _id: {
      $in: [
        "demo-event-001",
        "demo-event-002"
      ]
    }
  });

  await db.collection("alerts").deleteMany({
    _id: {
      $in: [
        "demo-alert-001",
        "demo-alert-002"
      ]
    }
  });
}

async function insertTestDocuments(db) {
  await db.collection("sensor_events").updateOne(
    { _id: "demo-event-001" },
    {
      $setOnInsert: {
        sensor_id: "MTR-B0-T0",
        building_id: 0,
        site_id: 0,
        event_type: "MAINTENANCE",
        timestamp: new Date("2026-01-15T10:00:00Z"),
        description: "Evento de mantenimiento de prueba",
        source: "demo",
        metadata: {
          note: "Documento de prueba; no procede del dataset"
        }
      }
    },
    { upsert: true }
  );

  await db.collection("alerts").updateOne(
    { _id: "demo-alert-001" },
    {
      $setOnInsert: {
        alert_type: "HIGH_CONSUMPTION",
        severity: "HIGH",
        status: "OPEN",
        timestamp: new Date("2026-01-15T10:05:00Z"),
        sensor_id: "MTR-B0-T0",
        building_id: 0,
        site_id: 0,
        message: "Alerta de prueba por consumo elevado",
        threshold: 100,
        observed_value: 125,
        source: "demo",
        metadata: {
          note: "Documento de prueba; no procede del dataset"
        }
      }
    },
    { upsert: true }
  );

  console.log("Documentos de prueba para eventos y alertas preparados.");
}

async function importCsv(db, fileName) {
  const filePath = path.join(DATA_DIRECTORY, fileName);

  if (!fs.existsSync(filePath)) {
    throw new Error(
      `No se encontro ${filePath}. ` +
      "Extrae los CSV en la carpeta data/."
    );
  }

  const readings = db.collection("sensor_readings");

  const parser = fs
    .createReadStream(filePath)
    .pipe(
      parse({
        columns: true,
        bom: true,
        skip_empty_lines: true,
        trim: true
      })
    );

  let batch = [];
  let processed = 0;

  console.log(`\nProcesando ${fileName}...`);

  for await (const row of parser) {
     if (
      MAX_ROWS_PER_FILE > 0 &&
      processed + batch.length >= MAX_ROWS_PER_FILE
    ) {
      break;
    }
    const document = transformRow(row, fileName);
    const { _id, ...fields } = document;

    /*
     * _id no se modifica dentro de $set porque MongoDB
     * considera ese campo inmutable. En un upsert, el filtro
     * conserva el identificador para evitar duplicados.
     */
    batch.push({
      updateOne: {
        filter: { _id },
        update: { $set: fields },
        upsert: true
      }
    });

    if (batch.length >= BATCH_SIZE) {
      await readings.bulkWrite(batch, {
        ordered: false
      });

      processed += batch.length;
      batch = [];

      if (processed % 20000 === 0) {
        console.log(
          `${fileName}: ${processed.toLocaleString("en-US")} filas procesadas`
        );
      }
    }
  }

  if (batch.length > 0) {
    await readings.bulkWrite(batch, {
      ordered: false
    });

    processed += batch.length;
  }

  console.log(
    `${fileName}: carga terminada; ` +
    `${processed.toLocaleString("en-US")} filas procesadas.`
  );

  return processed;
}

async function createIndexes(db) {
  const readings = db.collection("sensor_readings");
  const events = db.collection("sensor_events");
  const alerts = db.collection("alerts");

  /*
   * Los indices de lecturas se crean despues de la carga
   * para reducir el costo de escritura inicial.
   */
  await readings.createIndex(
    { sensor_id: 1, timestamp: -1 },
    { name: "idx_readings_sensor_timestamp" }
  );

  await readings.createIndex(
    { building_id: 1, timestamp: -1 },
    { name: "idx_readings_building_timestamp" }
  );

  await readings.createIndex(
    { site_id: 1, timestamp: -1 },
    { name: "idx_readings_site_timestamp" }
  );

  await readings.createIndex(
    { meter: 1, timestamp: -1 },
    { name: "idx_readings_meter_timestamp" }
  );

  await events.createIndex(
    { sensor_id: 1, timestamp: -1 },
    { name: "idx_events_sensor_timestamp" }
  );

  await events.createIndex(
    { event_type: 1, timestamp: -1 },
    { name: "idx_events_type_timestamp" }
  );

  await events.createIndex(
    { building_id: 1, timestamp: -1 },
    { name: "idx_events_building_timestamp" }
  );

  await alerts.createIndex(
    { status: 1, severity: 1, timestamp: -1 },
    { name: "idx_alerts_status_severity_timestamp" }
  );

  await alerts.createIndex(
    { sensor_id: 1, timestamp: -1 },
    { name: "idx_alerts_sensor_timestamp" }
  );

  await alerts.createIndex(
    { building_id: 1, status: 1 },
    { name: "idx_alerts_building_status" }
  );

  console.log("Indices creados o verificados.");
}

async function main() {
  const client = new MongoClient(MONGO_URI);

  try {
    await client.connect();

    console.log("Conexion con MongoDB establecida.");

    const db = client.db(DATABASE_NAME);

    await ensureCollections(db);
    await removeOldDemoRecords(db);

    await insertTestDocuments(db);

    let totalProcessed = 0;

    for (const fileName of CSV_FILES) {
      totalProcessed += await importCsv(db, fileName);
    }

    await createIndexes(db);

    console.log("\nCarga finalizada.");
    console.log(`Base de datos: ${DATABASE_NAME}`);

    console.log(
      `Filas procesadas en esta ejecucion: ` +
      `${totalProcessed.toLocaleString("en-US")}`
    );

    console.log(
      `Lecturas almacenadas: ` +
      `${(
        await db.collection("sensor_readings").countDocuments()
      ).toLocaleString("en-US")}`
    );

    console.log(
      `Eventos almacenados: ` +
      `${(
        await db.collection("sensor_events").countDocuments()
      ).toLocaleString("en-US")}`
    );

    console.log(
      `Alertas almacenadas: ` +
      `${(
        await db.collection("alerts").countDocuments()
      ).toLocaleString("en-US")}`
    );
  } catch (error) {
    console.error("\nError durante la carga:");
    console.error(error);
    process.exitCode = 1;
  } finally {
    await client.close();
  }
}

main();