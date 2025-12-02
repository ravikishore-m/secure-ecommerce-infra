import crypto from "crypto";
import express from "express";
import helmet from "helmet";
import cors from "cors";
import pino from "pino";
import pinoHttp from "pino-http";
import { collectDefaultMetrics, Registry, Histogram } from "prom-client";
import dotenv from "dotenv";

dotenv.config();

const SERVICE_NAME = process.env.SERVICE_NAME ?? "orders";
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

app.post("/orders", (req, res) => {
  req.log.info({ payload: req.body }, "Order received");
  res.status(202).json({ id: crypto.randomUUID(), status: "processing" });
});

app.listen(PORT, () => logger.info({ port: PORT, service: SERVICE_NAME }, "Service started"));

