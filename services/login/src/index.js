import express from "express";
import helmet from "helmet";
import cors from "cors";
import pino from "pino";
import pinoHttp from "pino-http";
import { collectDefaultMetrics, Registry, Histogram } from "prom-client";
import dotenv from "dotenv";
import {
  AdminCreateUserCommand,
  AdminInitiateAuthCommand,
  AdminGetUserCommand,
  AdminSetUserPasswordCommand,
  CognitoIdentityProviderClient,
} from "@aws-sdk/client-cognito-identity-provider";
import { randomUUID } from "crypto";
import { z } from "zod";
import { initDb, query } from "../../common/db.js";

dotenv.config();

const SERVICE_NAME = process.env.SERVICE_NAME ?? "login";
const PORT = process.env.PORT ?? 3000;

const logger = pino({
  level: process.env.LOG_LEVEL ?? "info",
});

const metricsRegistry = new Registry();
collectDefaultMetrics({ register: metricsRegistry });

const requestHistogram = new Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.1, 0.5, 1, 2, 5],
  registers: [metricsRegistry],
});

const cognitoRegion = process.env.COGNITO_REGION ?? process.env.AWS_REGION ?? "us-east-1";
const cognitoClient = new CognitoIdentityProviderClient({
  region: cognitoRegion,
});
const userPoolId = process.env.COGNITO_USER_POOL_ID;
const clientId = process.env.COGNITO_CLIENT_ID;

if (!userPoolId || !clientId) {
  logger.warn("Cognito variables missing; signup/login endpoints will fail");
}

const app = express();
app.use(
  helmet({
    contentSecurityPolicy: false,
  }),
);
app.use(cors({ origin: "*" }));
app.use(express.json());
app.use(
  pinoHttp({
    logger,
  }),
);

app.use((req, res, next) => {
  const end = requestHistogram.startTimer({
    method: req.method,
    route: req.path,
  });
  res.on("finish", () => {
    end({ status_code: res.statusCode });
  });
  next();
});

app.get("/", (_req, res) => {
  res.status(200).send(`Welcome to the ${SERVICE_NAME} service`);
});

app.get("/healthz", (_req, res) => {
  res.status(200).json({ status: "ok", service: SERVICE_NAME });
});

app.get("/livez", (_req, res) => {
  res.status(200).send("alive");
});

app.get("/metrics", async (_req, res) => {
  res.set("Content-Type", metricsRegistry.contentType);
  res.end(await metricsRegistry.metrics());
});

const signupSchema = z.object({
  email: z.string().email(),
  password: z.string().min(12),
  name: z.string().min(1),
});

app.post("/auth/signup", async (req, res, next) => {
  try {
    const { email, password, name } = signupSchema.parse(req.body);
    const tempPassword = `${randomUUID().slice(0, 8)}!Aa1`;
    const createResp = await cognitoClient.send(
      new AdminCreateUserCommand({
        UserPoolId: userPoolId,
        Username: email,
        TemporaryPassword: tempPassword,
        UserAttributes: [
          { Name: "email", Value: email },
          { Name: "name", Value: name },
        ],
        MessageAction: "SUPPRESS",
      }),
    );

    await cognitoClient.send(
      new AdminSetUserPasswordCommand({
        UserPoolId: userPoolId,
        Username: email,
        Password: password,
        Permanent: true,
      }),
    );

    const userSub =
      createResp.User?.Attributes?.find((attr) => attr.Name === "sub")?.Value ??
      createResp.User?.Username ??
      randomUUID();

    await query(
      `INSERT INTO users (id, email, full_name, cognito_sub)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name, cognito_sub = EXCLUDED.cognito_sub`,
      [randomUUID(), email, name, userSub],
    );

    res.status(201).json({ message: "User created", email });
  } catch (err) {
    next(err);
  }
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

app.post("/auth/login", async (req, res, next) => {
  try {
    const { email, password } = loginSchema.parse(req.body);
    const authResp = await cognitoClient.send(
      new AdminInitiateAuthCommand({
        UserPoolId: userPoolId,
        ClientId: clientId,
        AuthFlow: "ADMIN_USER_PASSWORD_AUTH",
        AuthParameters: {
          USERNAME: email,
          PASSWORD: password,
        },
      }),
    );

    const cognitoUser = await cognitoClient.send(
      new AdminGetUserCommand({
        UserPoolId: userPoolId,
        Username: email,
      }),
    );

    const cognitoSub =
      cognitoUser.UserAttributes?.find((attr) => attr.Name === "sub")?.Value ?? randomUUID();
    const fullName =
      cognitoUser.UserAttributes?.find((attr) => attr.Name === "name")?.Value ?? email.split("@")[0];

    const dbUser = await query(
      `INSERT INTO users (id, email, full_name, cognito_sub)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name, cognito_sub = EXCLUDED.cognito_sub
       RETURNING id, email, full_name`,
      [randomUUID(), email, fullName, cognitoSub],
    );

    res.json({
      tokens: authResp.AuthenticationResult,
      profile: dbUser.rows[0] ?? null,
    });
  } catch (err) {
    next(err);
  }
});

app.get("/users", async (_req, res, next) => {
  try {
    const { rows } = await query("SELECT id, email, full_name FROM users ORDER BY created_at DESC LIMIT 20");
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

app.use((err, req, res, _next) => {
  req.log.error(err);
  res.status(500).json({ message: err.message ?? "Internal error" });
});

initDb()
  .then(() => {
    app.listen(PORT, () => {
      logger.info({ port: PORT, service: SERVICE_NAME }, "Service started");
    });
  })
  .catch((error) => {
    logger.error(error, "failed to initialize database schema");
    process.exit(1);
  });

