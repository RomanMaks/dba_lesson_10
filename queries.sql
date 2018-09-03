-- Создание БД
  CREATE DATABASE store;

-- Типы:
  -- Прошедшие события
    CREATE TYPE events AS ENUM ('create', 'price', 'delete');

-- Создание таблиц:
  -- Товары
    CREATE TABLE products (
      id SERIAL PRIMARY KEY,
      vendor_code CHAR(11) UNIQUE CHECK (length(vendor_code) = 11), -- артикул товара
      name VARCHAR(100) CHECK (length(name) > 0), -- наименование
      cost NUMERIC(15, 2) NOT NULL CHECK (cost > 0), -- стоимость
      picture VARCHAR(500) NULL, -- ссылка на изображение товара
      admission_at DATE NOT NULL, -- Добавлен
      in_stock INTEGER CHECK (in_stock >= 0), -- товара на складе
      description TEXT NULL, -- описание
      properties jsonb NULL, -- характеристики
      cat_id INTEGER[] NULL, -- категории
      brand_id INTEGER NULL  -- бренд
    );

  -- Поиск по товарам
    CREATE TABLE search_by_products (
      product_id INTEGER NOT NULL UNIQUE,
      lexeme_name tsvector,
      lexeme_description tsvector
    );

  -- Прошедшие события
    CREATE TABLE happened_events (
      id SERIAL PRIMARY KEY NOT NULL,
      product_id INTEGER NOT NULL, -- товар
      event events NOT NULL, -- событие
      old_cost NUMERIC(15, 2), -- старая стоимость
      new_cost NUMERIC(15, 2), -- новая стоимость
      happened_at TIMESTAMP NOT NULL -- произошло в
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

  -- Продукты с поиском
    ALTER TABLE search_by_products
    ADD FOREIGN KEY (product_id)
    REFERENCES products(id)
    ON UPDATE CASCADE
    ON DELETE CASCADE;

-- Представления:
  -- Новые товары (сортировка от более новых к старым)
    CREATE VIEW new_products AS
    SELECT products.*
    FROM happened_events
      INNER JOIN products ON happened_events.product_id = products.id
    WHERE event = 'create'
    ORDER BY happened_events.happened_at DESC 

-- Триггеры:
  -- Удаление товара, изменение цены, создание нового
    CREATE OR REPLACE FUNCTION process_products_audit() RETURNS TRIGGER AS $$
      BEGIN
        IF (TG_OP = 'DELETE') THEN
          INSERT INTO happened_events(product_id, event, old_cost, new_cost, happened_at)
          VALUES(OLD.id, 'delete', OLD.cost, null, CURRENT_TIMESTAMP);
          RETURN OLD;
        ELSIF ((TG_OP = 'UPDATE') AND (OLD.cost != NEW.cost)) THEN
          INSERT INTO happened_events(product_id, event, old_cost, new_cost, happened_at)
          VALUES(OLD.id, 'price', OLD.cost, NEW.cost, CURRENT_TIMESTAMP);
          RETURN NEW;
        ELSIF (TG_OP = 'INSERT') THEN
          INSERT INTO happened_events(product_id, event, old_cost, new_cost, happened_at)
          VALUES(NEW.id, 'create', null, NEW.cost, CURRENT_TIMESTAMP);
          RETURN NEW;
        END IF;

        RETURN NULL; -- возвращаемое значение для триггера AFTER не имеет значения
      END;
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER products_audit
    AFTER INSERT OR UPDATE OR DELETE ON products
      FOR EACH ROW EXECUTE PROCEDURE process_products_audit();

  -- Управлять наличием товаров на складе
    CREATE OR REPLACE FUNCTION track_quantity_in_stock_audit() RETURNS TRIGGER AS $$
      BEGIN
        IF (TG_OP = 'DELETE') THEN
          UPDATE products
          SET in_stock = in_stock + OLD.quantity
          WHERE id = OLD.product_id;
          RETURN OLD;
        ELSIF (TG_OP = 'UPDATE') THEN
          UPDATE products
          SET in_stock = in_stock + NEW.quantity
          WHERE id = NEW.product_id;
          RETURN NEW;
        ELSEIF (TG_OP = 'INSERT') THEN
          UPDATE products
          SET in_stock = in_stock - NEW.quantity
          WHERE id = NEW.product_id;
          RETURN NEW;
        END IF;
    
        RETURN NULL;
      END;
    $$ LANGUAGE plpgsql;
    
    CREATE TRIGGER track_quantity_in_stock
    AFTER INSERT OR UPDATE OR DELETE ON order_items
      FOR EACH ROW EXECUTE PROCEDURE track_quantity_in_stock_audit();

  -- Действия с лексемами
    CREATE OR REPLACE FUNCTION procedure_actions_with_lexemes() RETURNS TRIGGER AS $$
      BEGIN
        IF ((TG_OP = 'UPDATE') AND ((OLD.name != NEW.name) OR (OLD.description != NEW.description))) THEN      
          UPDATE search_by_products 
          SET lexeme_name = to_tsvector(NEW.name), lexeme_description = to_tsvector(NEW.description)
          WHERE product_id = NEW.id;      
          RETURN NEW;
        ELSIF (TG_OP = 'INSERT') THEN
          INSERT INTO search_by_products(product_id, lexeme_name, lexeme_description)
          VALUES(NEW.id, to_tsvector(NEW.name), to_tsvector(NEW.description));
          RETURN NEW;
        END IF;
    
        RETURN NULL; -- возвращаемое значение для триггера AFTER не имеет значения
      END;
    $$ LANGUAGE plpgsql;
    
    CREATE TRIGGER actions_with_lexemes
    AFTER INSERT OR UPDATE ON products
      FOR EACH ROW EXECUTE PROCEDURE procedure_actions_with_lexemes();

-- Индексы:
  -- Индекс GIN для полнотекстового поиска
    CREATE INDEX index_search_by_products
    ON search_by_products
    USING gin
    (
      (
        setweight(lexeme_name, 'A') ||
        setweight(coalesce(lexeme_description, ''), 'B')
      )
    )

-- Запросы:
  -- Поиск по товарам
    SELECT p.*
    FROM search_by_products
      INNER JOIN products p on search_by_products.product_id = p.id
    WHERE (
      setweight(lexeme_name, 'A') ||
      setweight(coalesce(lexeme_description, ''), 'B')
    ) @@ plainto_tsquery('russian', 'с пуговицами');

  -- Выбрать все заказы за сегодня
    SELECT *
    FROM orders
    WHERE date_at >= current_date

  -- Посмотреть все заказы у конкретного пользователя
    SELECT products.*, order_items.quantity
    FROM orders
      INNER JOIN order_items ON orders.id = order_items.order_id
      INNER JOIN products ON order_items.product_id = products.id
    WHERE user_id = 2