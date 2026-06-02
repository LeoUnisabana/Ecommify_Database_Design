-- ========================================
-- ECOMMIFY DATABASE - POSTGRESQL SCHEMA
-- 02_create_tables.sql
-- ========================================
-- Descripción: Creación de todas las tablas del módulo transaccional
-- Autor: Olist DB Team
-- Fecha: 25 de mayo de 2026
-- Normalización: 3FN (Tercera Forma Normal)
-- ========================================

-- ========================================
-- 1. TABLAS MAESTRAS (Sin dependencias)
-- ========================================

-- Tabla: CUSTOMERS
CREATE TABLE customers (
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_unique_id VARCHAR(32) UNIQUE NOT NULL,
    customer_zip_code_prefix VARCHAR(10) NOT NULL,
    customer_city VARCHAR(50) NOT NULL,
    customer_state CHAR(2) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_customers_state_length CHECK (LENGTH(customer_state) = 2),
    CONSTRAINT chk_customers_zip_format CHECK (customer_zip_code_prefix ~ '^\d{5}$')
);

COMMENT ON TABLE customers IS 'Clientes únicos del marketplace Olist';
COMMENT ON COLUMN customers.customer_id IS 'ID único del cliente (generado por sistema)';
COMMENT ON COLUMN customers.customer_unique_id IS 'CPF hasheado (SHA-256) para identificar persona física';
COMMENT ON COLUMN customers.customer_zip_code_prefix IS 'Primeros 5 dígitos del código postal brasileño (CEP)';
COMMENT ON COLUMN customers.customer_state IS 'Sigla del estado: SP, RJ, MG, etc.';

-- Tabla: SELLERS
CREATE TABLE sellers (
    seller_id VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10) NOT NULL,
    seller_city VARCHAR(50) NOT NULL,
    seller_state CHAR(2) NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_sellers_state_length CHECK (LENGTH(seller_state) = 2),
    CONSTRAINT chk_sellers_zip_format CHECK (seller_zip_code_prefix ~ '^\d{5}$')
);

COMMENT ON TABLE sellers IS 'Vendedores (comercios) que ofrecen productos en el marketplace';
COMMENT ON COLUMN sellers.seller_zip_code_prefix IS 'Código postal del almacén/tienda del seller';

-- Tabla: PRODUCT_CATEGORY_NAME_TRANSLATION
CREATE TABLE product_category_name_translation (
    product_category_name VARCHAR(50) PRIMARY KEY,
    product_category_name_english VARCHAR(50) UNIQUE NOT NULL
);

COMMENT ON TABLE product_category_name_translation IS 'Traducción de categorías PT-BR ↔ EN (71 categorías)';

-- Tabla: PRODUCTS
CREATE TABLE products (
    product_id VARCHAR(32) PRIMARY KEY,
    product_category_name VARCHAR(50),
    product_name_length INT CHECK (product_name_length >= 0),
    product_description_length INT CHECK (product_description_length >= 0),
    product_photos_qty INT DEFAULT 0 CHECK (product_photos_qty >= 0),
    product_weight_g INT CHECK (product_weight_g > 0),
    product_length_cm INT CHECK (product_length_cm > 0),
    product_height_cm INT CHECK (product_height_cm > 0),
    product_width_cm INT CHECK (product_width_cm > 0),
    product_attributes JSONB,  -- Atributos dinámicos según categoría
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_products_category 
        FOREIGN KEY (product_category_name) 
        REFERENCES product_category_name_translation(product_category_name)
        ON DELETE SET NULL
);

COMMENT ON TABLE products IS 'Catálogo de productos (master data)';
COMMENT ON COLUMN products.product_name_length IS 'Longitud del nombre original (metadata), texto completo en MongoDB';
COMMENT ON COLUMN products.product_attributes IS 'Atributos específicos por categoría (voltaje, talla, color, etc.) en formato JSONB';

-- ========================================
-- 2. TABLAS TRANSACCIONALES
-- ========================================

-- Tabla: ORDERS
CREATE TABLE orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    order_status order_status_type NOT NULL DEFAULT 'created',
    order_purchase_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_approved_at TIMESTAMP WITHOUT TIME ZONE,
    order_delivered_carrier_date TIMESTAMP WITHOUT TIME ZONE,
    order_delivered_customer_date TIMESTAMP WITHOUT TIME ZONE,
    order_estimated_delivery_date TIMESTAMP WITHOUT TIME ZONE,
    
    CONSTRAINT fk_orders_customer 
        FOREIGN KEY (customer_id) 
        REFERENCES customers(customer_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_orders_delivery_after_purchase
        CHECK (order_delivered_customer_date IS NULL OR 
               order_delivered_customer_date >= order_purchase_timestamp),
    
    CONSTRAINT chk_orders_approval_after_purchase
        CHECK (order_approved_at IS NULL OR 
               order_approved_at >= order_purchase_timestamp)
);

COMMENT ON TABLE orders IS 'Pedidos realizados - tabla central transaccional OLTP';
COMMENT ON COLUMN orders.order_status IS 'Estado actual del pedido (8 estados posibles, ver order_status_type)';
COMMENT ON COLUMN orders.order_purchase_timestamp IS 'Momento en que se creó el pedido';
COMMENT ON COLUMN orders.order_delivered_customer_date IS 'Fecha real de entrega al cliente (NULL si aún no entregado)';

-- Tabla: ORDER_ITEMS
CREATE TABLE order_items (
    order_id VARCHAR(32),
    order_item_id INT,
    product_id VARCHAR(32) NOT NULL,
    seller_id VARCHAR(32) NOT NULL,
    shipping_limit_date TIMESTAMP WITHOUT TIME ZONE,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    freight_value NUMERIC(10,2) DEFAULT 0 CHECK (freight_value >= 0),
    
    PRIMARY KEY (order_id, order_item_id),
    
    CONSTRAINT fk_items_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(order_id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_items_product 
        FOREIGN KEY (product_id) 
        REFERENCES products(product_id)
        ON DELETE RESTRICT,
    
    CONSTRAINT fk_items_seller 
        FOREIGN KEY (seller_id) 
        REFERENCES sellers(seller_id)
        ON DELETE RESTRICT
);

COMMENT ON TABLE order_items IS 'Productos individuales dentro de cada pedido (líneas de detalle)';
COMMENT ON COLUMN order_items.order_item_id IS 'Secuencial dentro del pedido (1, 2, 3...)';
COMMENT ON COLUMN order_items.price IS 'Precio unitario del producto en el momento de la compra';
COMMENT ON COLUMN order_items.freight_value IS 'Valor del flete para este item específico';

-- Tabla: ORDER_PAYMENTS
CREATE TABLE order_payments (
    order_id VARCHAR(32),
    payment_sequential INT,
    payment_type payment_type_enum NOT NULL,
    payment_installments INT NOT NULL CHECK (payment_installments BETWEEN 1 AND 24),
    payment_value NUMERIC(10,2) NOT NULL CHECK (payment_value > 0),
    
    PRIMARY KEY (order_id, payment_sequential),
    
    CONSTRAINT fk_payments_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(order_id)
        ON DELETE CASCADE
);

COMMENT ON TABLE order_payments IS 'Pagos asociados a pedidos (soporta split payments)';
COMMENT ON COLUMN order_payments.payment_sequential IS 'Orden del pago (1, 2, 3...) para split payments';
COMMENT ON COLUMN order_payments.payment_installments IS 'Número de cuotas (1-24), solo aplica para credit_card';
COMMENT ON COLUMN order_payments.payment_value IS 'Valor de este pago (suma de todos debe = total del pedido)';

-- ========================================
-- 3. TABLAS DE REFERENCIA
-- ========================================

-- Tabla: GEOLOCATION
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat NUMERIC(10,8),
    geolocation_lng NUMERIC(10,8),
    geolocation_city VARCHAR(50),
    geolocation_state CHAR(2),
    
    PRIMARY KEY (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng)
);

COMMENT ON TABLE geolocation IS 'Coordenadas geográficas por código postal (1M+ registros)';
COMMENT ON COLUMN geolocation.geolocation_lat IS 'Latitud (formato decimal: -23.5505)';
COMMENT ON COLUMN geolocation.geolocation_lng IS 'Longitud (formato decimal: -46.6333)';

-- ========================================
-- 4. TABLAS DE ANALYTICS (opcional en PostgreSQL)
-- ========================================

-- Tabla: ORDER_REVIEWS (considerar moverla a MongoDB)
CREATE TABLE order_reviews (
    review_id VARCHAR(32) PRIMARY KEY,
    order_id VARCHAR(32) UNIQUE NOT NULL,
    review_score INT NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title VARCHAR(100),
    review_comment_message TEXT,
    review_creation_date TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    review_answer_timestamp TIMESTAMP WITHOUT TIME ZONE,
    
    CONSTRAINT fk_reviews_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(order_id)
        ON DELETE CASCADE,
    
    CONSTRAINT chk_review_answer_after_creation
        CHECK (review_answer_timestamp IS NULL OR 
               review_answer_timestamp >= review_creation_date)
);

COMMENT ON TABLE order_reviews IS 'Reviews de clientes (considerar migrar a MongoDB para mejor análisis de texto)';
COMMENT ON COLUMN order_reviews.review_score IS 'Puntuación de 1 (pésimo) a 5 (excelente)';

-- ========================================
-- 5. TRIGGERS PARA UPDATED_AT
-- ========================================

-- Función genérica para actualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger a customers
CREATE TRIGGER trg_customers_updated_at
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Aplicar trigger a products
CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- 6. RESUMEN FINAL
-- ========================================

DO $$
DECLARE
    v_tables_count INT;
BEGIN
    SELECT COUNT(*) INTO v_tables_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CREACIÓN DE ESQUEMA COMPLETADA';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total de tablas creadas: %', v_tables_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Tablas maestras:';
    RAISE NOTICE '  - customers (clientes)';
    RAISE NOTICE '  - sellers (vendedores)';
    RAISE NOTICE '  - products (productos)';
    RAISE NOTICE '  - product_category_name_translation (categorías)';
    RAISE NOTICE '';
    RAISE NOTICE 'Tablas transaccionales:';
    RAISE NOTICE '  - orders (pedidos)';
    RAISE NOTICE '  - order_items (items de pedidos)';
    RAISE NOTICE '  - order_payments (pagos)';
    RAISE NOTICE '';
    RAISE NOTICE 'Tablas de referencia:';
    RAISE NOTICE '  - geolocation (georeferencia)';
    RAISE NOTICE '  - order_reviews (opiniones)';
    RAISE NOTICE '';
    RAISE NOTICE 'Próximo paso: Ejecutar 03_create_indexes.sql';
    RAISE NOTICE '========================================';
END $$;
