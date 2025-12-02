import express from "express";
import helmet from "helmet";
import cors from "cors";
import pino from "pino";
import pinoHttp from "pino-http";
import { collectDefaultMetrics, Registry, Histogram } from "prom-client";
import dotenv from "dotenv";
import { Pool } from "pg";
import { randomUUID } from "crypto";

dotenv.config();

const SERVICE_NAME = process.env.SERVICE_NAME ?? "catalog";
const PORT = process.env.PORT ?? 3000;

const logger = pino({ level: process.env.LOG_LEVEL ?? "info" });
const metricsRegistry = new Registry();
collectDefaultMetrics({ register: metricsRegistry });

const requestHistogram = new Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.1, 0.5, 1, 2, 5],
  registers: [metricsRegistry],
});

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DB_SSL === "disable" ? false : { rejectUnauthorized: false },
});

const seedProducts = [
  { sku: "sku-1", name: "Trail Runner", price: 129.0, description: "All-weather running shoe" },
  { sku: "sku-2", name: "City Backpack", price: 89.0, description: "Water-resistant everyday backpack" },
  { sku: "sku-3", name: "Noise Canceling Buds", price: 149.0, description: "Bluetooth earbuds with ANC" },
];

async function seed() {
  for (const product of seedProducts) {
    await pool.query(
      `INSERT INTO products (id, sku, name, price, description)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (sku) DO NOTHING`,
      [randomUUID(), product.sku, product.name, product.price, product.description],
    );
  }
}

const app = express();
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: "*" }));
app.use(express.json());
app.use(pinoHttp({ logger }));

app.use((req, res, next) => {
  const end = requestHistogram.startTimer({
    method: req.method,
    route: req.path,
  });
  res.on("finish", () => end({ status_code: res.statusCode }));
  next();
});

app.get("/", (_req, res) => res.send(`Welcome to the ${SERVICE_NAME} service`));
app.get("/healthz", (_req, res) => res.json({ status: "ok", service: SERVICE_NAME }));
app.get("/livez", (_req, res) => res.send("alive"));
app.get("/metrics", async (_req, res) => {
  res.set("Content-Type", metricsRegistry.contentType);
  res.end(await metricsRegistry.metrics());
});

app.get("/catalog", async (_req, res, next) => {
  try {
    const result = await pool.query("SELECT id, sku, name, price, description FROM products ORDER BY name");
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
});

app.post("/catalog", async (req, res, next) => {
  try {
    const { sku, name, price, description } = req.body;
    const id = randomUUID();
    await pool.query(
      "INSERT INTO products (id, sku, name, price, description) VALUES ($1,$2,$3,$4,$5)",
      [id, sku, name, price, description],
    );
    res.status(201).json({ id });
  } catch (err) {
    next(err);
  }
});

app.post("/catalog/seed", async (_req, res, next) => {
  try {
    await seed();
    res.status(201).json({ message: "Catalog seeded" });
  } catch (err) {
    next(err);
  }
});

app.use((err, req, res, _next) => {
  req.log.error(err);
  res.status(500).json({ message: err.message ?? "Catalog error" });
});

app.listen(PORT, async () => {
  await seed().catch((err) => logger.error(err, "Catalog seed failed"));
  logger.info({ port: PORT, service: SERVICE_NAME }, "Service started");
});

