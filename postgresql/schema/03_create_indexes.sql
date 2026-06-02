-- ========================================
-- ECOMMIFY DATABASE - POSTGRESQL SCHEMA
-- 03_create_indexes.sql
-- ========================================
-- Descripción: Índices de performance para optimización de queries
-- Autor: Olist DB Team
-- Fecha: 25 de mayo de 2026
-- ========================================

-- NOTA: Las claves primarias ya tienen índices automáticos
-- Solo creamos índices explicitos para:
-- 1. Foreign keys (para JOINs rápidos)
-- 2. Columnas usadas en WHERE/ORDER BY frecuentemente
-- 3. Índices compuestos para queries específicas

-- ========================================
-- 1. ÍNDICES EN CUSTOMERS
-- ========================================

-- Búsqueda por unique_id (CPF)
CREATE INDEX idx_customers_unique_id ON customers(customer_unique_id);

-- Filtros por estado (analytics por región)
CREATE INDEX idx_customers_state ON customers(customer_state);

-- Búsqueda por código postal
CREATE INDEX idx_customers_zip ON customers(customer_zip_code_prefix);

-- Índice compuesto para queries_by_location
CREATE INDEX idx_customers_

_location ON customers(customer_state, customer_city);

COMMENT ON INDEX idx_customers_unique_id IS 'Búsqueda rápida por CPF hasheado';
COMMENT ON INDEX idx_customers_state IS 'Análisis de clientes por estado';

-- ========================================
-- 2. ÍNDICES EN ORDERS
-- ========================================

-- Foreign key: búsqueda de pedidos por cliente (JOIN frecuente)
CREATE INDEX idx_orders_customer ON orders(customer_id);

-- Filtros por estado del pedido
CREATE INDEX idx_orders_status ON orders(order_status);

-- Ordenamiento por fecha de compra (historial cronológico)
CREATE INDEX idx_orders_purchase_date ON orders(order_purchase_timestamp DESC);

-- Índice compuesto para dashboard de ventas
CREATE INDEX idx_orders_status_date 
ON orders(order_status, order_purchase_timestamp DESC);

-- Índice compuesto para queries de clientes activos
CREATE INDEX idx_orders_customer_status 
ON orders(customer_id, order_status, order_purchase_timestamp DESC);

-- Índice parcial: solo pedidos entregados (optimiza reportes)
CREATE INDEX idx_orders_delivered 
ON orders(order_purchase_timestamp DESC) 
WHERE order_status = 'delivered';

-- Índice BRIN para timestamps (eficiente para datos temporales grandes)
CREATE INDEX idx_orders_purchase_brin 
ON orders USING BRIN (order_purchase_timestamp);

COMMENT ON INDEX idx_orders_customer IS 'JOIN Orders-Customers (query más frecuente)';
COMMENT ON INDEX idx_orders_delivered IS 'Índice parcial para pedidos completados (reportes)';

-- ========================================
-- 3. ÍNDICES EN ORDER_ITEMS
-- ========================================

-- Foreign keys
CREATE INDEX idx_items_product ON order_items(product_id);
CREATE INDEX idx_items_seller ON order_items(seller_id);
CREATE INDEX idx_items_order ON order_items(order_id);

-- Índice para análisis de precios
CREATE INDEX idx_items_price ON order_items(price DESC);

-- Índice parcial: items con precio alto (análisis de productos premium)
CREATE INDEX idx_items_premium 
ON order_items(product_id, price) 
WHERE price > 100;

COMMENT ON INDEX idx_items_product IS 'JOIN Order_Items-Products (catálogo)';
COMMENT ON INDEX idx_items_seller IS 'JOIN Order_Items-Sellers (análisis de vendedores)';

-- ========================================
-- 4. ÍNDICES EN ORDER_PAYMENTS
-- ========================================

-- Foreign key
CREATE INDEX idx_payments_order ON order_payments(order_id);

-- Análisis de métodos de pago
CREATE INDEX idx_payments_type ON order_payments(payment_type);

-- Índice compuesto para análisis de cuotas
CREATE INDEX idx_payments_type_installments 
ON order_payments(payment_type, payment_installments);

COMMENT ON INDEX idx_payments_type IS 'Análisis de popularidad de métodos de pago';

-- ========================================
-- 5. ÍNDICES EN PRODUCTS
-- ========================================

-- Foreign key: categoría
CREATE INDEX idx_products_category ON products(product_category_name);

-- Análisis de dimensiones (cálculo de flete)
CREATE INDEX idx_products_weight ON products(product_weight_g);

-- Índice GIN para búsquedas en JSONB attributes
CREATE INDEX idx_products_attributes_gin 
ON products USING GIN (product_attributes);

-- Índice GIN para path operations (ejemplo: buscar por brand)
CREATE INDEX idx_products_attributes_path_gin 
ON products USING GIN (product_attributes jsonb_path_ops);

COMMENT ON INDEX idx_products_attributes_gin IS 'Búsquedas en atributos dinámicos (voltaje, talla, color)';

-- ========================================
-- 6. ÍNDICES EN GEOLOCATION
-- ========================================

-- Búsqueda por ciudad/estado
CREATE INDEX idx_geolocation_city ON geolocation(geolocation_city);
CREATE INDEX idx_geolocation_state ON geolocation(geolocation_state);

-- Índice compuesto para queries por zip_code
CREATE INDEX idx_geolocation_zip 
ON geolocation(geolocation_zip_code_prefix);

-- ========================================
-- 7. ÍNDICES EN ORDER_REVIEWS
-- ========================================

-- Foreign key: order_id (ya es UNIQUE, tiene índice automático)

-- Análisis de scores
CREATE INDEX idx_reviews_score ON order_reviews(review_score);

-- Ordenamiento por fecha
CREATE INDEX idx_reviews_creation_date 
ON order_reviews(review_creation_date DESC);

-- Índice compuesto para filtros de dashboard
CREATE INDEX idx_reviews_score_date 
ON order_reviews(review_score, review_creation_date DESC);

-- ========================================
-- 8. ÍNDICES DE TEXTO COMPLETO (opcional)
-- ========================================

-- Requiere extensión pg_trgm
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Índice GIN para búsqueda fuzzy en categorías
-- CREATE INDEX idx_category_english_trgm 
-- ON product_category_name_translation 
-- USING GIN (product_category_name_english gin_trgm_ops);

-- ========================================
-- 9. ANÁLISIS Y RESUMEN
-- ========================================

-- Actualizar estadísticas para query planner
ANALYZE customers;
ANALYZE orders;
ANALYZE order_items;
ANALYZE order_payments;
ANALYZE products;
ANALYZE sellers;
ANALYZE geolocation;
ANALYZE order_reviews;

-- Resumen de índices creados
DO $$
DECLARE
    v_indexes_count INT;
BEGIN
    SELECT COUNT(*) INTO v_indexes_count
    FROM pg_indexes
    WHERE schemaname = 'public';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ÍNDICES CREADOS EXITOSAMENTE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Total de índices en esquema: %', v_indexes_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Tipos de índices:';
    RAISE NOTICE '  - B-Tree (default): JOINs, ORDER BY, WHERE';
    RAISE NOTICE '  - GIN: JSONB, búsquedas de texto';
    RAISE NOTICE '  - BRIN: Tiempo (particionamiento futuro)';
    RAISE NOTICE '  - Parciales: Optimización de queries específicas';
    RAISE NOTICE '';
    RAISE NOTICE 'Impacto esperado:';
    RAISE NOTICE '  - Queries transaccionales: <100ms (p95)';
    RAISE NOTICE '  - JOINs complejos: 10-50x más rápidos';
    RAISE NOTICE '  - Agregaciones: 5-20x más rápidas';
    RAISE NOTICE '';
    RAISE NOTICE 'Próximo paso: Ejecutar 04_create_constraints.sql';
    RAISE NOTICE '========================================';
END $$;
