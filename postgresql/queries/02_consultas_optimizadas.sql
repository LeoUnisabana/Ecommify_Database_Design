-- ========================================
-- ECOMMIFY DATABASE - CONSULTAS OPTIMIZADAS
-- 02_consultas_optimizadas.sql
-- ========================================
-- Descripción: Consultas DESPUÉS de aplicar optimizaciones
-- Propósito: Documentar mejoras de rendimiento
-- Fecha: 9 de junio de 2026
-- ========================================

-- TÉCNICAS DE OPTIMIZACIÓN APLICADAS:
-- 1. Reescritura de subconsultas a JOINs
-- 2. Uso de CTEs (Common Table Expressions) para claridad
-- 3. Eliminación de funciones en WHERE (EXTRACT, CAST)
-- 4. Optimización de agregaciones con filtros pre-aplicados
-- 5. Uso de EXISTS en lugar de IN cuando apropiado
-- 6. Simplificación de expresiones CASE
-- 7. Aprovechamiento de índices parciales y compuestos

-- ========================================
-- CONSULTA OPTIMIZADA #1: Historial de Pedidos por Cliente
-- ========================================
-- OPTIMIZACIONES APLICADAS:
-- - Asegurar índice en orders(customer_id) para Index Scan
-- - Pre-filtrar antes de JOIN cuando posible

-- VERSIÓN OPTIMIZADA:
WITH customer_orders AS (
    SELECT 
        order_id,
        order_purchase_timestamp,
        order_status,
        order_delivered_customer_date
    FROM orders
    WHERE customer_id = 'CUSTOMER_ID_EJEMPLO'  -- Index Scan aquí
    ORDER BY order_purchase_timestamp DESC
    LIMIT 20  -- Limitar ANTES del JOIN
)
SELECT 
    co.order_id,
    co.order_purchase_timestamp,
    co.order_status,
    co.order_delivered_customer_date,
    COUNT(oi.order_item_id) as total_items,
    SUM(oi.price + oi.freight_value) as total_value
FROM customer_orders co
JOIN order_items oi ON co.order_id = oi.order_id
GROUP BY co.order_id, co.order_purchase_timestamp, co.order_status, co.order_delivered_customer_date
ORDER BY co.order_purchase_timestamp DESC;

-- MEJORA ESPERADA: 40-60% reducción en tiempo de ejecución
-- RAZÓN: Limitar filas antes del JOIN reduce trabajo de agregación

-- ========================================
-- CONSULTA OPTIMIZADA #2: Análisis de Ventas por Categoría
-- ========================================
-- OPTIMIZACIONES APLICADAS:
-- - CTE para pre-filtrar orders delivered
-- - Evitar LEFT JOIN innecesario (usar INNER JOIN)
-- - Asegurar índice parcial en orders(order_status) WHERE order_status = 'delivered'

-- VERSIÓN OPTIMIZADA:
WITH delivered_orders AS (
    SELECT order_id
    FROM orders
    WHERE order_status = 'delivered'
        AND order_purchase_timestamp >= '2017-01-01'
        AND order_purchase_timestamp < '2018-01-01'
    -- Index Scan con índice parcial o compuesto (order_status, order_purchase_timestamp)
)
SELECT 
    COALESCE(pcnt.product_category_name_english, 'Uncategorized') as category,
    COUNT(DISTINCT oi.order_id) as total_orders,
    COUNT(oi.order_item_id) as total_items_sold,
    SUM(oi.price) as total_revenue,
    AVG(oi.price) as avg_price,
    MIN(oi.price) as min_price,
    MAX(oi.price) as max_price,
    SUM(oi.freight_value) as total_freight
FROM delivered_orders do
JOIN order_items oi ON do.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation pcnt 
    ON p.product_category_name = pcnt.product_category_name
GROUP BY pcnt.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 20;

-- MEJORA ESPERADA: 50-70% reducción
-- RAZÓN: Pre-filtrar orders reduce filas en JOINs subsecuentes

-- ========================================
-- CONSULTA OPTIMIZADA #3: Resumen de Pagos por Pedido
-- ========================================
-- OPTIMIZACIONES APLICADAS:
-- - Usar rango de fechas con índice BRIN o B-tree
-- - Evitar funciones de fecha en WHERE
-- - Optimizar STRING_AGG con DISTINCT

-- VERSIÓN OPTIMIZADA:
SELECT 
    o.order_id,
    o.customer_id,
    o.order_status,
    COUNT(op.payment_sequential) as payment_methods_count,
    COALESCE(SUM(op.payment_value), 0) as total_paid,
    MAX(op.payment_installments) as max_installments,
    STRING_AGG(DISTINCT op.payment_type::TEXT, ', ' ORDER BY op.payment_type::TEXT) as payment_types
FROM orders o
LEFT JOIN order_payments op ON o.order_id = op.order_id
WHERE o.order_purchase_timestamp >= (CURRENT_DATE - INTERVAL '30 days')::timestamp
    AND o.order_purchase_timestamp < (CURRENT_DATE + INTERVAL '1 day')::timestamp
GROUP BY o.order_id, o.customer_id, o.order_status
HAVING COALESCE(SUM(op.payment_value), 0) > 500
ORDER BY total_paid DESC;

-- MEJORA ESPERADA: 30-40% reducción
-- RAZÓN: Rango explícito permite uso de BRIN o B-tree index

-- ========================================
-- CONSULTA OPTIMIZADA #4: Top Productos Más Vendidos
-- ========================================
-- OPTIMIZACIONES APLICADAS:
-- - Pre-filtrar orders delivered
-- - Simplificar agregaciones
-- - Usar índice parcial en orders

-- VERSIÓN OPTIMIZADA:
SELECT 
    p.product_id,
    p.product_category_name,
    COUNT(DISTINCT oi.order_id) as orders_count,
    SUM(oi.order_item_id) as total_items_sold,
    SUM(oi.price * oi.order_item_id) as total_revenue,
    ROUND(AVG(oi.price)::numeric, 2) as avg_unit_price,
    SUM(oi.freight_value) as total_freight_cost,
    COUNT(DISTINCT oi.seller_id) as sellers_count
FROM products p
INNER JOIN order_items oi ON p.product_id = oi.product_id
WHERE EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.order_id = oi.order_id
        AND o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NOT NULL
)
GROUP BY p.product_id, p.product_category_name
HAVING COUNT(DISTINCT oi.order_id) >= 10
ORDER BY total_revenue DESC
LIMIT 50;

-- MEJORA ESPERADA: 40-50% reducción
-- RAZÓN: EXISTS es más eficiente que JOIN cuando solo necesitamos verificar existencia

-- ========================================
-- CONSULTA OPTIMIZADA #5: Pedidos Pendientes de Entrega
-- ========================================
-- OPTIMIZACIONES APLICADAS:
-- - Eliminar EXTRACT de SELECT (mover a aplicación si es posible)
-- - Simplificar CASE expressions
-- - Usar índice compuesto (order_status, order_purchase_timestamp)
-- - Pre-calcular constantes de fecha

-- VERSIÓN OPTIMIZADA:
WITH pending_orders AS (
    SELECT 
        o.order_id,
        o.customer_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_estimated_delivery_date,
        o.order_delivered_carrier_date,
        -- Pre-calcular prioridad para evitar CASE complejo en ORDER BY
        CASE 
            WHEN o.order_estimated_delivery_date < CURRENT_DATE THEN 1
            WHEN o.order_estimated_delivery_date <= CURRENT_DATE + 2 THEN 2
            ELSE 3
        END as priority_level
    FROM orders o
    WHERE o.order_status IN ('processing', 'shipped')
        AND o.order_delivered_customer_date IS NULL
        AND o.order_purchase_timestamp >= (CURRENT_DATE - INTERVAL '60 days')::timestamp
)
SELECT 
    po.order_id,
    po.customer_id,
    c.customer_state,
    c.customer_city,
    po.order_status,
    po.order_purchase_timestamp,
    po.order_estimated_delivery_date,
    po.order_delivered_carrier_date,
    (CURRENT_DATE - po.order_purchase_timestamp::date) as days_since_purchase,
    CASE po.priority_level
        WHEN 1 THEN 'DELAYED'
        WHEN 2 THEN 'URGENT'
        ELSE 'ON_TIME'
    END as delivery_priority
FROM pending_orders po
JOIN customers c ON po.customer_id = c.customer_id
ORDER BY po.priority_level, po.order_estimated_delivery_date ASC;

-- MEJORA ESPERADA: 35-45% reducción
-- RAZÓN: CTE con pre-cálculo de prioridad + índice compuesto

-- ========================================
-- CONSULTA OPTIMIZADA #6: Revenue por Vendedor
-- ========================================
-- OPTIMIZACIONES APLICADAS:
-- - Pre-filtrar orders antes de JOINs
-- - Evitar cálculos redundantes (price + freight calculado una sola vez)

-- VERSIÓN OPTIMIZADA:
WITH delivered_period AS (
    SELECT order_id
    FROM orders
    WHERE order_status = 'delivered'
        AND order_purchase_timestamp >= '2017-01-01'
        AND order_purchase_timestamp < '2018-01-01'
),
seller_revenues AS (
    SELECT 
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) as total_orders,
        COUNT(oi.order_item_id) as total_items,
        SUM(oi.price) as gross_revenue,
        SUM(oi.freight_value) as freight_revenue,
        SUM(oi.price + oi.freight_value) as total_revenue,
        ROUND(AVG(oi.price)::numeric, 2) as avg_item_price,
        MAX(oi.price) as max_item_price
    FROM delivered_period dp
    JOIN order_items oi ON dp.order_id = oi.order_id
    GROUP BY oi.seller_id
    HAVING SUM(oi.price) > 1000
)
SELECT 
    sr.*,
    s.seller_state,
    s.seller_city
FROM seller_revenues sr
JOIN sellers s ON sr.seller_id = s.seller_id
ORDER BY sr.total_revenue DESC
LIMIT 100;

-- MEJORA ESPERADA: 45-55% reducción
-- RAZÓN: CTEs separan lógica, permitiendo al optimizador elegir mejor plan

-- ========================================
-- CONSULTA OPTIMIZADA #7: Análisis Geográfico de Ventas
-- ========================================
-- OPTIMIZACIONES APLICADAS:
-- - Pre-filtrar orders delivered
-- - Calcular delivery_days sin EXTRACT en agregación
-- - Reducir COUNT(DISTINCT) donde sea posible

-- VERSIÓN OPTIMIZADA:
WITH delivered_orders AS (
    SELECT 
        order_id,
        customer_id,
        order_purchase_timestamp,
        order_delivered_customer_date,
        (order_delivered_customer_date::date - order_purchase_timestamp::date) as delivery_days
    FROM orders
    WHERE order_status = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND order_purchase_timestamp >= '2017-01-01'
)
SELECT 
    c.customer_state,
    s.seller_state,
    COUNT(DISTINCT do.order_id) as total_orders,
    COUNT(DISTINCT do.customer_id) as unique_customers,
    COUNT(DISTINCT oi.seller_id) as unique_sellers,
    ROUND(SUM(oi.price)::numeric, 2) as total_sales,
    ROUND(AVG(oi.price)::numeric, 2) as avg_order_value,
    ROUND(AVG(do.delivery_days)::numeric, 1) as avg_delivery_days
FROM delivered_orders do
JOIN customers c ON do.customer_id = c.customer_id
JOIN order_items oi ON do.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
GROUP BY c.customer_state, s.seller_state
HAVING COUNT(DISTINCT do.order_id) >= 100
ORDER BY total_sales DESC;

-- MEJORA ESPERADA: 50-65% reducción
-- RAZÓN: Pre-calcular delivery_days elimina EXTRACT en agregación

-- ========================================
-- CONSULTA OPTIMIZADA #8: Búsqueda de Productos por Atributos JSONB
-- ========================================
-- OPTIMIZACIONES APLICADAS:
-- - Requiere índice GIN en product_attributes
-- - Evitar cast en WHERE cuando sea posible
-- - Usar operador @> para aprovechar GIN

-- VERSIÓN OPTIMIZADA (requiere índice GIN):
-- CREATE INDEX idx_products_attributes_gin ON products USING GIN (product_attributes);

-- Ejemplo 1: Búsqueda optimizada con GIN
SELECT 
    p.product_id,
    p.product_category_name,
    p.product_weight_g,
    p.product_attributes->>'voltage' as voltage,
    p.product_attributes->>'color' as color,
    p.product_attributes
FROM products p
WHERE p.product_category_name = 'electronics'  -- Filtro simple primero (B-tree index)
    AND p.product_attributes @> '{"voltage": "220V"}'  -- Luego GIN index
LIMIT 100;

-- Ejemplo 2: Búsqueda por clave + valor numérico (requiere expresión)
-- NOTA: El cast impide uso de índice GIN, considerar crear índice de expresión
SELECT 
    p.product_id,
    p.product_category_name,
    p.product_attributes
FROM products p
WHERE p.product_attributes ? 'warranty_months'
    AND (p.product_attributes->>'warranty_months')::INT >= 12
LIMIT 100;

-- ALTERNATIVA: Índice de expresión (más avanzado)
-- CREATE INDEX idx_products_warranty_months 
-- ON products ((product_attributes->>'warranty_months')::INT)
-- WHERE product_attributes ? 'warranty_months';

-- MEJORA ESPERADA: 85-95% reducción con índice GIN
-- RAZÓN: GIN permite búsquedas extremadamente rápidas en JSONB

-- ========================================
-- CONSULTA OPTIMIZADA #9: Análisis de Retrasos en Entregas
-- ========================================
-- OPTIMIZACIONES APLICADAS:
-- - Pre-calcular delay_days sin EXTRACT
-- - Usar FILTER en lugar de CASE para agregaciones condicionales

-- VERSIÓN OPTIMIZADA:
WITH order_delays AS (
    SELECT 
        order_status,
        CASE 
            WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1
            ELSE 0
        END as is_delayed,
        (order_delivered_customer_date::date - order_estimated_delivery_date::date) as delay_days
    FROM orders
    WHERE order_delivered_customer_date IS NOT NULL
        AND order_purchase_timestamp >= '2017-01-01'
)
SELECT 
    order_status,
    COUNT(*) as total_orders,
    SUM(is_delayed) as delayed_orders,
    ROUND(100.0 * SUM(is_delayed) / COUNT(*), 2) as delay_percentage,
    ROUND(AVG(CASE WHEN is_delayed = 1 THEN delay_days END)::numeric, 1) as avg_delay_days
FROM order_delays
GROUP BY order_status
ORDER BY delay_percentage DESC;

-- MEJORA ESPERADA: 40-50% reducción
-- RAZÓN: Pre-calcular en CTE es más eficiente que múltiples CASE en agregaciones

-- ALTERNATIVA PostgreSQL 11+: Usar FILTER clause
-- SUM(is_delayed) puede escribirse como: COUNT(*) FILTER (WHERE is_delayed = 1)

-- ========================================
-- CONSULTA OPTIMIZADA #10: Detalle Completo de Pedido
-- ========================================
-- OPTIMIZACIONES APLICADAS:
-- - Ninguna necesaria si existen índices FK
-- - Esta query ya es óptima con búsqueda por PK

-- VERSIÓN OPTIMIZADA (sin cambios, ya óptima):
SELECT 
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status,
    o.order_delivered_customer_date,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    oi.order_item_id,
    p.product_category_name,
    oi.price,
    oi.freight_value,
    s.seller_city,
    s.seller_state,
    op.payment_type,
    op.payment_installments,
    op.payment_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN order_payments op ON o.order_id = op.order_id
WHERE o.order_id = 'ORDER_ID_EJEMPLO'
ORDER BY oi.order_item_id, op.payment_sequential;

-- MEJORA ESPERADA: 0-10% (ya era óptima)
-- RAZÓN: Búsqueda por PK + Nested Loop Joins son apropiados aquí

-- ========================================
-- FIN DEL ARCHIVO - CONSULTAS OPTIMIZADAS
-- ========================================

-- RESUMEN DE TÉCNICAS APLICADAS:
-- ✅ 1. CTEs para pre-filtrado y claridad
-- ✅ 2. EXISTS en lugar de JOIN cuando apropiado
-- ✅ 3. Pre-cálculo de expresiones complejas
-- ✅ 4. Eliminación de funciones en WHERE/agregaciones
-- ✅ 5. Índices especializados (GIN, parciales, BRIN)
-- ✅ 6. Simplificación de CASE expressions
-- ✅ 7. ROUND para reducir precisión innecesaria

-- PRÓXIMOS PASOS:
-- 1. Ejecutar EXPLAIN ANALYZE en versiones optimizadas
-- 2. Comparar métricas antes/después
-- 3. Documentar porcentaje de mejora
-- 4. Implementar índices especializados necesarios
