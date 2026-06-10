-- ========================================
-- ECOMMIFY DATABASE - CONSULTAS CRÍTICAS
-- 01_consultas_criticas_base.sql
-- ========================================
-- Descripción: Consultas críticas ANTES de optimización
-- Propósito: Establecer línea base de rendimiento
-- Fecha: 9 de junio de 2026
-- ========================================

-- INSTRUCCIONES:
-- 1. Ejecutar EXPLAIN (ANALYZE, BUFFERS) antes de cada consulta
-- 2. Documentar métricas base en tabla de resultados
-- 3. Identificar cuellos de botella
-- 4. Aplicar optimizaciones en archivo 02_consultas_optimizadas.sql

-- ========================================
-- CONSULTA CRÍTICA #1: Historial de Pedidos por Cliente
-- ========================================
-- Frecuencia: Muy Alta (perfil de usuario, historial de compras)
-- Complejidad: Media (2 JOINs)
-- Problema esperado: Seq Scan en orders por customer_id

-- Ejecutar análisis con:
-- EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) 

-- Query Base (SIN OPTIMIZAR):
SELECT 
    o.order_id,
    o.order_purchase_timestamp,
    o.order_status,
    o.order_delivered_customer_date,
    COUNT(oi.order_item_id) as total_items,
    SUM(oi.price + oi.freight_value) as total_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.customer_id = 'CUSTOMER_ID_EJEMPLO'  -- Reemplazar con ID real
GROUP BY o.order_id, o.order_purchase_timestamp, o.order_status, o.order_delivered_customer_date
ORDER BY o.order_purchase_timestamp DESC
LIMIT 20;

-- ANÁLISIS ESPERADO:
-- - Nested Loop Join entre orders y order_items
-- - Posible Seq Scan si no hay índice en orders.customer_id
-- - Sorting adicional para ORDER BY

-- ========================================
-- CONSULTA CRÍTICA #2: Análisis de Ventas por Categoría
-- ========================================
-- Frecuencia: Alta (dashboard de analytics)
-- Complejidad: Alta (4 JOINs, agregaciones)
-- Problema esperado: Múltiples Seq Scans, Hash Joins pesados

SELECT 
    pcnt.product_category_name_english as category,
    COUNT(DISTINCT oi.order_id) as total_orders,
    COUNT(oi.order_item_id) as total_items_sold,
    SUM(oi.price) as total_revenue,
    AVG(oi.price) as avg_price,
    MIN(oi.price) as min_price,
    MAX(oi.price) as max_price,
    SUM(oi.freight_value) as total_freight
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation pcnt 
    ON p.product_category_name = pcnt.product_category_name
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp < '2018-01-01'
GROUP BY pcnt.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 20;

-- ANÁLISIS ESPERADO:
-- - Múltiples Hash Joins (tablas grandes sin índices apropiados)
-- - Posible Seq Scan en orders por filtro de fecha
-- - Agregaciones pesadas en memoria

-- ========================================
-- CONSULTA CRÍTICA #3: Resumen de Pagos por Pedido
-- ========================================
-- Frecuencia: Alta (validación de pagos, reconciliación)
-- Complejidad: Baja (1 JOIN)
-- Problema esperado: Agregaciones sin índice

SELECT 
    o.order_id,
    o.customer_id,
    o.order_status,
    COUNT(op.payment_sequential) as payment_methods_count,
    SUM(op.payment_value) as total_paid,
    MAX(op.payment_installments) as max_installments,
    STRING_AGG(DISTINCT op.payment_type::TEXT, ', ') as payment_types
FROM orders o
LEFT JOIN order_payments op ON o.order_id = op.order_id
WHERE o.order_purchase_timestamp >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY o.order_id, o.customer_id, o.order_status
HAVING SUM(op.payment_value) > 500
ORDER BY total_paid DESC;

-- ANÁLISIS ESPERADO:
-- - Seq Scan en orders por filtro de fecha reciente
-- - Posible índice BRIN podría ayudar
-- - Hash Aggregate para GROUP BY

-- ========================================
-- CONSULTA CRÍTICA #4: Top Productos Más Vendidos
-- ========================================
-- Frecuencia: Media (reportes de inventario, marketing)
-- Complejidad: Alta (múltiples agregaciones)
-- Problema esperado: Sort pesado, falta de índices

SELECT 
    p.product_id,
    p.product_category_name,
    COUNT(DISTINCT oi.order_id) as orders_count,
    SUM(oi.order_item_id) as total_items_sold,
    SUM(oi.price * oi.order_item_id) as total_revenue,
    AVG(oi.price) as avg_unit_price,
    SUM(oi.freight_value) as total_freight_cost,
    COUNT(DISTINCT oi.seller_id) as sellers_count
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
GROUP BY p.product_id, p.product_category_name
HAVING COUNT(DISTINCT oi.order_id) >= 10
ORDER BY total_revenue DESC
LIMIT 50;

-- ANÁLISIS ESPERADO:
-- - Join entre 3 tablas grandes
-- - Sort Top-N para LIMIT 50
-- - Posible mejora con índices parciales

-- ========================================
-- CONSULTA CRÍTICA #5: Pedidos Pendientes de Entrega
-- ========================================
-- Frecuencia: Muy Alta (operaciones logísticas)
-- Complejidad: Media (filtros temporales complejos)
-- Problema esperado: Filtros en múltiples columnas timestamp

SELECT 
    o.order_id,
    o.customer_id,
    c.customer_state,
    c.customer_city,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_estimated_delivery_date,
    o.order_delivered_carrier_date,
    EXTRACT(DAY FROM (CURRENT_TIMESTAMP - o.order_purchase_timestamp)) as days_since_purchase,
    CASE 
        WHEN o.order_estimated_delivery_date < CURRENT_DATE THEN 'DELAYED'
        WHEN o.order_estimated_delivery_date - CURRENT_DATE <= 2 THEN 'URGENT'
        ELSE 'ON_TIME'
    END as delivery_priority
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status IN ('processing', 'shipped')
    AND o.order_delivered_customer_date IS NULL
    AND o.order_purchase_timestamp >= CURRENT_DATE - INTERVAL '60 days'
ORDER BY 
    CASE 
        WHEN o.order_estimated_delivery_date < CURRENT_DATE THEN 1
        WHEN o.order_estimated_delivery_date - CURRENT_DATE <= 2 THEN 2
        ELSE 3
    END,
    o.order_estimated_delivery_date ASC;

-- ANÁLISIS ESPERADO:
-- - Múltiples filtros en timestamps (posible Seq Scan)
-- - Función EXTRACT impide uso de índices
-- - Sort complejo con CASE

-- ========================================
-- CONSULTA CRÍTICA #6: Revenue por Vendedor
-- ========================================
-- Frecuencia: Media (comisiones, reportes de sellers)
-- Complejidad: Alta (agregación + JOINs)
-- Problema esperado: Hash Join pesado, agregaciones complejas

SELECT 
    s.seller_id,
    s.seller_state,
    s.seller_city,
    COUNT(DISTINCT oi.order_id) as total_orders,
    COUNT(oi.order_item_id) as total_items,
    SUM(oi.price) as gross_revenue,
    SUM(oi.freight_value) as freight_revenue,
    SUM(oi.price + oi.freight_value) as total_revenue,
    AVG(oi.price) as avg_item_price,
    MAX(oi.price) as max_item_price
FROM sellers s
JOIN order_items oi ON s.seller_id = oi.seller_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp < '2018-01-01'
GROUP BY s.seller_id, s.seller_state, s.seller_city
HAVING SUM(oi.price) > 1000
ORDER BY total_revenue DESC
LIMIT 100;

-- ANÁLISIS ESPERADO:
-- - Join entre 3 tablas
-- - Posible Seq Scan en orders por fecha
-- - Sort para TOP 100

-- ========================================
-- CONSULTA CRÍTICA #7: Análisis Geográfico de Ventas
-- ========================================
-- Frecuencia: Baja (reportes ejecutivos)
-- Complejidad: Alta (5 JOINs, agregaciones por región)
-- Problema esperado: Múltiples Seq Scans, muchos Hash Joins

SELECT 
    c.customer_state,
    s.seller_state,
    COUNT(DISTINCT o.order_id) as total_orders,
    COUNT(DISTINCT o.customer_id) as unique_customers,
    COUNT(DISTINCT oi.seller_id) as unique_sellers,
    SUM(oi.price) as total_sales,
    AVG(oi.price) as avg_order_value,
    AVG(EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp))) 
        as avg_delivery_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
    AND o.order_delivered_customer_date IS NOT NULL
    AND o.order_purchase_timestamp >= '2017-01-01'
GROUP BY c.customer_state, s.seller_state
HAVING COUNT(DISTINCT o.order_id) >= 100
ORDER BY total_sales DESC;

-- ANÁLISIS ESPERADO:
-- - 4 Hash Joins consecutivos
-- - Múltiples agregaciones (COUNT DISTINCT costoso)
-- - Función EXTRACT en AVG impide optimizaciones

-- ========================================
-- CONSULTA CRÍTICA #8: Búsqueda de Productos por Atributos JSONB
-- ========================================
-- Frecuencia: Media (filtros avanzados en catálogo)
-- Complejidad: Media (requiere índices GIN)
-- Problema esperado: Seq Scan en JSONB sin índice GIN

-- Ejemplo 1: Búsqueda por voltaje específico
SELECT 
    p.product_id,
    p.product_category_name,
    p.product_weight_g,
    p.product_attributes->>'voltage' as voltage,
    p.product_attributes->>'color' as color,
    p.product_attributes
FROM products p
WHERE p.product_attributes @> '{"voltage": "220V"}'
    AND p.product_category_name = 'electronics'
LIMIT 100;

-- Ejemplo 2: Búsqueda por clave existente (operador ?)
SELECT 
    p.product_id,
    p.product_category_name,
    p.product_attributes
FROM products p
WHERE p.product_attributes ? 'warranty_months'
    AND (p.product_attributes->>'warranty_months')::INT >= 12
LIMIT 100;

-- ANÁLISIS ESPERADO:
-- - Seq Scan en products sin índice GIN
-- - Operador @> requiere GIN para ser eficiente
-- - Cast (p.product_attributes->>'key')::INT impide uso de índice

-- ========================================
-- CONSULTA CRÍTICA #9: Análisis de Retrasos en Entregas
-- ========================================
-- Frecuencia: Media (KPIs de logística)
-- Complejidad: Media (cálculos de fechas)
-- Problema esperado: Seq Scan, funciones complejas

SELECT 
    o.order_status,
    COUNT(*) as total_orders,
    COUNT(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
               THEN 1 END) as delayed_orders,
    ROUND(
        100.0 * COUNT(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
                           THEN 1 END) / COUNT(*), 
        2
    ) as delay_percentage,
    AVG(
        EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date))
    ) as avg_delay_days
FROM orders o
WHERE o.order_delivered_customer_date IS NOT NULL
    AND o.order_purchase_timestamp >= '2017-01-01'
GROUP BY o.order_status
ORDER BY delay_percentage DESC;

-- ANÁLISIS ESPERADO:
-- - Seq Scan por filtros en timestamps
-- - Múltiples agregaciones condicionales
-- - EXTRACT y cálculos de fechas

-- ========================================
-- CONSULTA CRÍTICA #10: Detalle Completo de Pedido (Customer View)
-- ========================================
-- Frecuencia: Muy Alta (detalle de orden)
-- Complejidad: Alta (múltiples JOINs)
-- Problema esperado: Nested Loops múltiples

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
WHERE o.order_id = 'ORDER_ID_EJEMPLO'  -- Reemplazar con ID real
ORDER BY oi.order_item_id, op.payment_sequential;

-- ANÁLISIS ESPERADO:
-- - Múltiples Nested Loop Joins (apropiado para búsqueda por PK)
-- - Index Scans en todas las FKs
-- - Debería ser rápido SI existen todos los índices FK

-- ========================================
-- FIN DEL ARCHIVO - CONSULTAS BASE
-- ========================================

-- PRÓXIMOS PASOS:
-- 1. Ejecutar EXPLAIN (ANALYZE, BUFFERS) en cada consulta
-- 2. Documentar Planning Time, Execution Time, y Shared Buffers
-- 3. Identificar operaciones costosas (Seq Scan, Sort, Hash Aggregate)
-- 4. Aplicar optimizaciones en archivo 02_consultas_optimizadas.sql
-- 5. Crear índices especializados en archivo 03_indices_especializados.sql
-- 6. Comparar rendimiento antes/después

-- TEMPLATE PARA DOCUMENTACIÓN:
/*
CONSULTA: #X - Nombre
EJECUCIÓN: ANTES DE OPTIMIZACIÓN

Planning Time: XX.XXX ms
Execution Time: XXX.XXX ms
Total Cost: XXXXX
Rows Returned: XXX
Shared Buffers Hit: XXXX
Shared Buffers Read: XXXX

PROBLEMAS IDENTIFICADOS:
- Problema 1: ...
- Problema 2: ...

OPTIMIZACIONES PROPUESTAS:
- Optimización 1: ...
- Optimización 2: ...
*/
