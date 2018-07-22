-- Создание БД
  CREATE DATABASE store;

-- Создание таблиц:  
  -- Товары
    CREATE TABLE products
    (
      id SERIAL PRIMARY KEY,
      vendor_code CHAR(11) UNIQUE CHECK (length(vendor_code) = 11),
      name VARCHAR(100) CHECK (length(name) > 0),
      price INTEGER CHECK (price > 0),
      picture VARCHAR(500),
      admission_at DATE,
      in_stock INTEGER CHECK (in_stock > 0),
      description TEXT,
      properties jsonb NULL,
      cat_id INTEGER[] NULL,
      brand_id INTEGER NULL
    );

  -- Категории
    CREATE TABLE categories (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) CHECK (length(name) > 0)
    );

  -- Бренды
    CREATE TABLE brands (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100)  CHECK (length(name) > 0)
    );

-- Связи:
  -- Продукты с брендами  
    ALTER TABLE products
    ADD FOREIGN KEY (brand_id)
    REFERENCES brands(id)
    ON UPDATE CASCADE
    ON DELETE SET NULL;