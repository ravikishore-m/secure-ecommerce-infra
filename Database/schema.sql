CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    cognito_sub TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY,
    sku TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS inventory (
    product_id UUID REFERENCES products(id),
    quantity INT NOT NULL DEFAULT 0,
    PRIMARY KEY (product_id)
);

CREATE TABLE IF NOT EXISTS carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    status TEXT DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cart_items (
    cart_id UUID REFERENCES carts(id),
    product_id UUID REFERENCES products(id),
    quantity INT NOT NULL,
    PRIMARY KEY (cart_id, product_id)
);

CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID REFERENCES carts(id),
    total NUMERIC(10,2),
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO products (id, sku, name, price, description)
VALUES
    (gen_random_uuid(), 'sku-1', 'Trail Runner', 129.00, 'All-weather running shoe'),
    (gen_random_uuid(), 'sku-2', 'City Backpack', 89.00, 'Water-resistant everyday backpack'),
    (gen_random_uuid(), 'sku-3', 'Noise Canceling Buds', 149.00, 'Bluetooth earbuds with ANC')
ON CONFLICT (sku) DO NOTHING;

