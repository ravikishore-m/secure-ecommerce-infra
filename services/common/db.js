import { Pool } from "pg";
import { randomUUID } from "crypto";

const {
  DATABASE_HOST,
  DATABASE_PORT = 5432,
  DATABASE_NAME,
  DATABASE_USER,
  DATABASE_PASSWORD,
} = process.env;

const pool = new Pool({
  host: DATABASE_HOST,
  port: Number(DATABASE_PORT),
  database: DATABASE_NAME,
  user: DATABASE_USER,
  password: DATABASE_PASSWORD,
  ssl: process.env.DB_SSL === "disable" ? false : { rejectUnauthorized: false },
});

const baseSchema = `
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  cognito_sub TEXT UNIQUE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY,
  sku TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10,2) NOT NULL,
  inventory INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS carts (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cart_items (
  cart_id UUID REFERENCES carts(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  quantity INTEGER NOT NULL,
  PRIMARY KEY (cart_id, product_id)
);

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  total NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'processing',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_items (
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  quantity INTEGER NOT NULL,
  price NUMERIC(10,2) NOT NULL,
  PRIMARY KEY (order_id, product_id)
);

CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY,
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id),
  amount NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'authorized',
  provider TEXT DEFAULT 'demo',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
`;

const seedProducts = [
  {
    sku: "SKU-FAIRWAY-001",
    name: "Trailblazer Running Shoes",
    price: 129.0,
    description: "Lightweight carbon-neutral shoes built for distance.",
    inventory: 50,
  },
  {
    sku: "SKU-CITYPACK-002",
    name: "City Explorer Backpack",
    price: 89.0,
    description: "30L everyday carry with waterproof zippers.",
    inventory: 120,
  },
  {
    sku: "SKU-SOUND-003",
    name: "Noise Canceling Buds",
    price: 149.0,
    description: "Spatial audio with adaptive noise cancelation.",
    inventory: 75,
  },
];

export async function initDb() {
  await pool.query(baseSchema);
  const { rows } = await pool.query("SELECT COUNT(*) AS count FROM products");
  if (Number(rows[0].count) === 0) {
    for (const product of seedProducts) {
      await pool.query(
        `INSERT INTO products (id, sku, name, description, price, inventory)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (sku) DO NOTHING`,
        [randomUUID(), product.sku, product.name, product.description, product.price, product.inventory],
      );
    }
  }
}

export async function withTransaction(handler) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await handler(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function query(text, params) {
  return pool.query(text, params);
}

export { pool };

