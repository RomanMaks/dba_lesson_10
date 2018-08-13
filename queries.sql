-- Создание БД
  CREATE DATABASE store;

-- Создание таблиц:
  -- Товары
    CREATE TABLE products (
      id SERIAL PRIMARY KEY,
      vendor_code CHAR(11) UNIQUE CHECK (length(vendor_code) = 11),
      name VARCHAR(100) CHECK (length(name) > 0),
      cost NUMERIC(15, 2) NOT NULL CHECK (cost > 0),
      picture VARCHAR(500) NULL,
      admission_at DATE NOT NULL,
      in_stock INTEGER CHECK (in_stock >= 0),
      description TEXT NULL,
      properties jsonb NULL,
      cat_id INTEGER[] NULL,
      brand_id INTEGER NULL
    );

  -- Категории
    CREATE TABLE categories (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) NOT NULL CHECK (length(name) > 0)
    );

  -- Бренды
    CREATE TABLE brands (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) NOT NULL CHECK (length(name) > 0)
    );

  -- Пользователи
    CREATE TABLE users (
      id SERIAL PRIMARY KEY,
      login VARCHAR(100) NOT NULL, -- логин
      password_hash VARCHAR(1000) NOT NULL, -- хеш пароля
      name VARCHAR(100) NOT NULL CHECK (length(name) > 0), -- Имя
      surname VARCHAR(100) NULL, -- Фамилия
      patronymic VARCHAR(100) NULL, -- Отчество
      phone VARCHAR(11) NOT NULL, -- Телефон
      email VARCHAR(100) NULL, -- Email адрес
      UNIQUE (password_hash, name, phone) -- Обязательные поля
    );

  -- Заказы
    CREATE TABLE orders (
      id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL, -- Пользователь
      date_at DATE NOT NULL, -- Дата заказа
      shipping_address TEXT NOT NULL -- Адрес доставки
    );

  -- Состав заказа
    CREATE TABLE order_items (
      product_id INTEGER NOT NULL, -- Товар
      order_id INTEGER NOT NULL, -- Заказ
      quantity INTEGER NOT NULL CHECK (quantity > 0), -- Количество заказанного товара
      PRIMARY KEY (product_id, order_id)
    );

-- Связи:
  -- Продукты с брендами  
    ALTER TABLE products
    ADD FOREIGN KEY (brand_id)
    REFERENCES brands(id)
    ON UPDATE CASCADE
    ON DELETE SET NULL; 

  -- Пользователи с заказами
    ALTER TABLE orders
    ADD FOREIGN KEY (user_id)
    REFERENCES users(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT; -- Если у пользователя есть заказ то мы не сможем его удалить

  -- Заказы со списком заказов
    ALTER TABLE order_items
    ADD FOREIGN KEY (order_id)
    REFERENCES orders(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

  -- Продукты со списком заказов
    ALTER TABLE order_items
    ADD FOREIGN KEY (product_id)
    REFERENCES products(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT; 