-- ========================================
-- ECOMMIFY DATABASE - ÍNDICES ESPECIALIZADOS
-- 04_indices_especializados_u4.sql
-- ========================================
-- Descripción: Índices avanzados para optimización U4
-- Propósito: Complementar índices básicos (03_create_indexes.sql)
-- Autor: Olist DB Team - Unidad 4
-- Fecha: 9 de junio de 2026
-- ========================================

-- NOTA: Este archivo contiene índices especializados adicionales
-- Los índices básicos (PK, FK simples) ya existen en 03_create_indexes.sql
-- Aquí implementamos: GIN, índices parciales, BRIN, compuestos avanzados

-- ========================================
-- SECCIÓN 1: ÍNDICES B-TREE COMPUESTOS AVANZADOS
-- ========================================

-- ÍNDICE COMPUESTO #1: Orders por Customer + Status + Date
-- Tipo: B-tree Compuesto (3 columnas)
-- Justificación: Query frecuente "historial de pedidos por cliente filtrado por estado"
-- Patrón optimizado: WHERE customer_id = X AND order_status = Y ORDER BY purchase_date DESC
-- Trade-offs: 
--   ✅ Optimiza la query #1 (historial de cliente)
--   ✅ Permite Index Only Scan en queries que solo necesitan estas columnas
--   ❌ Tamaño ~40% del tamaño de la tabla orders
--   ❌ Overhead en INSERT/UPDATE de orders

DROP INDEX IF EXISTS idx_orders_customer_status_date_advanced CASCADE;

CREATE INDEX idx_orders_customer_status_date_advanced 
ON orders (customer_id, order_status, order_purchase_timestamp DESC)
INCLUDE (order_delivered_customer_date);  -- Columna adicional para Index Only Scan

COMMENT ON INDEX idx_orders_customer_status_date_advanced IS 
'Índice compuesto avanzado para historial de pedidos por cliente. 
Orden de columnas optimizado: customer_id (alta selectividad) -> order_status -> timestamp.
INCLUDE permite Index Only Scan sin acceder a la tabla.';

-- Verificación de uso:
-- EXPLAIN (ANALYZE, BUFFERS) 
-- SELECT order_id, order_status, order_purchase_timestamp, order_delivered_customer_date
-- FROM orders
-- WHERE customer_id = 'xxx' AND order_status = 'delivered'
-- ORDER BY order_purchase_timestamp DESC LIMIT 10;
-- Esperado: Index Only Scan usando idx_orders_customer_status_date_advanced


-- ÍNDICE COMPUESTO #2: Order Items por Seller + Price
-- Tipo: B-tree Compuesto con ORDER DESC
-- Justificación: Análisis de productos más vendidos por vendedor
-- Patrón optimizado: WHERE seller_id = X ORDER BY price DESC

DROP INDEX IF EXISTS idx_order_items_seller_price CASCADE;

CREATE INDEX idx_order_items_seller_price 
ON order_items (seller_id, price DESC);

COMMENT ON INDEX idx_order_items_seller_price IS 
'Índice para reportes de revenue por vendedor ordenados por precio.
Útil para identificar productos premium de cada seller.';


-- ÍNDICE COMPUESTO #3: Orders por fecha + estado para analytics
-- Tipo: B-tree Compuesto con fecha primero (para rangos)
-- Justificación: Queries de analytics por período + filtro de estado
-- Patrón: WHERE purchase_date BETWEEN X AND Y AND order_status IN (...)

DROP INDEX IF EXISTS idx_orders_date_status_analytics CASCADE;

CREATE INDEX idx_orders_date_status_analytics 
ON orders (order_purchase_timestamp, order_status)
WHERE order_status IN ('delivered', 'shipped', 'invoiced');  -- Solo estados relevantes para analytics

COMMENT ON INDEX idx_orders_date_status_analytics IS 
'Índice parcial-compuesto para queries de analytics por período.
Solo incluye estados finales (delivered, shipped, invoiced) que representan ~85% de los pedidos.';


-- ========================================
-- SECCIÓN 2: ÍNDICES GIN (JSONB y Arrays)
-- ========================================

-- ÍNDICE GIN #1: Products - Atributos JSONB
-- Tipo: GIN (Generalized Inverted Index)
-- Justificación: Búsquedas en atributos dinámicos de productos (voltage, color, size, etc.)
-- Operadores soportados: @>, ?, ?|, ?&
-- Trade-offs:
--   ✅ Búsquedas en JSONB 90-95% más rápidas que Seq Scan
--   ✅ Soporta queries complejas: product_attributes @> '{"voltage": "220V", "color": "red"}'
--   ❌ Tamaño: 60-100% del tamaño de la columna JSONB
--   ❌ Construcción lenta (~30 seg para 32K productos)
--   ❌ Overhead significativo en INSERT/UPDATE

DROP INDEX IF EXISTS idx_products_attributes_gin CASCADE;

CREATE INDEX idx_products_attributes_gin 
ON products USING GIN (product_attributes);

COMMENT ON INDEX idx_products_attributes_gin IS 
'Índice GIN para búsquedas rápidas en atributos JSONB de productos.
Ejemplo de uso: WHERE product_attributes @> ''{"voltage": "220V"}''
CRÍTICO para queries de catálogo con filtros dinámicos por categoría.';

-- Verificación de uso:
-- EXPLAIN (ANALYZE, BUFFERS) 
-- SELECT product_id, product_attributes->>'voltage', product_attributes->>'color'
-- FROM products
-- WHERE product_attributes @> '{"voltage": "220V"}';
-- Esperado: Bitmap Index Scan usando idx_products_attributes_gin


-- ÍNDICE GIN #2: Products - Búsqueda por claves específicas
-- Tipo: GIN con operador jsonb_path_ops (más compacto)
-- Justificación: Si solo usamos operador @>, jsonb_path_ops es 30% más compacto
-- Trade-offs:
--   ✅ Tamaño 30% menor que GIN estándar
--   ✅ Más rápido para operador @>
--   ❌ NO soporta operadores ?, ?|, ?& (solo @>)

-- DESCOMENTAR si solo usamos @> y necesitamos optimizar espacio:
-- DROP INDEX IF EXISTS idx_products_attributes_gin_path CASCADE;
-- 
-- CREATE INDEX idx_products_attributes_gin_path 
-- ON products USING GIN (product_attributes jsonb_path_ops);
-- 
-- COMMENT ON INDEX idx_products_attributes_gin_path IS 
-- 'Índice GIN compacto (jsonb_path_ops) solo para operador @>.
-- 30% más pequeño que GIN estándar pero menos versátil.';


-- ÍNDICE GIN #3: Expresión en JSONB (warranty_months como entero)
-- Tipo: Índice de Expresión con GIN
-- Justificación: Búsquedas por warranty_months >= X sin cast en query
-- Nota: Esto es avanzado, requiere que la expresión coincida exactamente en queries

DROP INDEX IF EXISTS idx_products_warranty_months CASCADE;

CREATE INDEX idx_products_warranty_months 
ON products (((product_attributes->>'warranty_months')::INT))
WHERE product_attributes ? 'warranty_months';

COMMENT ON INDEX idx_products_warranty_months IS 
'Índice de expresión para búsquedas por meses de garantía.
Permite queries como: WHERE (product_attributes->>''warranty_months'')::INT >= 12
sin full table scan.';


-- ========================================
-- SECCIÓN 3: ÍNDICES PARCIALES
-- ========================================

-- ÍNDICE PARCIAL #1: Orders - Solo Delivered (70% de los pedidos)
-- Tipo: Índice Parcial B-tree
-- Justificación: Reportes de ventas solo usan pedidos entregados
-- Patrón: WHERE order_status = 'delivered' AND ...
-- Trade-offs:
--   ✅ Tamaño 70% menor que índice completo
--   ✅ Mantenimiento más rápido (solo actualiza pedidos delivered)
--   ✅ Queries de analytics son 60-80% más rápidas
--   ❌ Solo útil para queries que incluyen WHERE order_status = 'delivered'

DROP INDEX IF EXISTS idx_orders_delivered_date CASCADE;

CREATE INDEX idx_orders_delivered_date 
ON orders (order_purchase_timestamp DESC, order_delivered_customer_date)
WHERE order_status = 'delivered';

COMMENT ON INDEX idx_orders_delivered_date IS 
'Índice parcial para queries de analytics sobre pedidos entregados.
Cubre ~70% de los pedidos, reduciendo tamaño y mejorando performance.
DEBE incluir "WHERE order_status = ''delivered''" en la query para usarse.';

-- Tamaño estimado:
-- SELECT pg_size_pretty(pg_relation_size('idx_orders_delivered_date'));


-- ÍNDICE PARCIAL #2: Orders - Pedidos Pendientes (últimos 90 días)
-- Tipo: Índice Parcial para operaciones en tiempo real
-- Justificación: Operaciones logísticas solo consultan pedidos recientes pendientes
-- Trade-offs:
--   ✅ Extremadamente pequeño (solo ~5-10% de orders)
--   ✅ Óptimo para dashboard de logística
--   ❌ Requiere recreación periódica o usar función NOW() - INTERVAL

DROP INDEX IF EXISTS idx_orders_pending_recent CASCADE;

CREATE INDEX idx_orders_pending_recent 
ON orders (order_estimated_delivery_date, order_status)
WHERE order_status IN ('processing', 'shipped') 
    AND order_delivered_customer_date IS NULL;
    -- Nota: No podemos usar NOW() en WHERE de índice, usar función si necesario

COMMENT ON INDEX idx_orders_pending_recent IS 
'Índice parcial para pedidos pendientes de entrega.
Cubre solo ~15% de orders (processing + shipped), optimizado para logística en tiempo real.';


-- ÍNDICE PARCIAL #3: Order Items - Productos Premium (precio > $100)
-- Tipo: Índice Parcial para análisis de alto valor
-- Justificación: Reportes de productos premium son frecuentes
-- Cubre: ~10-15% de order_items

DROP INDEX IF EXISTS idx_order_items_premium CASCADE;

CREATE INDEX idx_order_items_premium 
ON order_items (product_id, price DESC, seller_id)
WHERE price > 100;

COMMENT ON INDEX idx_order_items_premium IS 
'Índice parcial para análisis de productos de alto valor (>$100).
Útil para reportes de revenue concentrado y análisis de productos premium.';


-- ÍNDICE PARCIAL #4: Customers - Estados con mayor volumen
-- Tipo: Índice Parcial geográfico
-- Justificación: 80% de los clientes están en 5 estados (SP, RJ, MG, PR, RS)

DROP INDEX IF EXISTS idx_customers_top_states CASCADE;

CREATE INDEX idx_customers_top_states 
ON customers (customer_state, customer_city, customer_zip_code_prefix)
WHERE customer_state IN ('SP', 'RJ', 'MG', 'PR', 'RS');

COMMENT ON INDEX idx_customers_top_states IS 
'Índice parcial para los 5 estados con mayor volumen de clientes (~80% del total).
Optimiza queries geográficas en regiones principales.';


-- ========================================
-- SECCIÓN 4: ÍNDICES BRIN (Para Datos Temporales Grandes)
-- ========================================

-- ÍNDICE BRIN #1: Orders - Purchase Timestamp
-- Tipo: BRIN (Block Range Index)
-- Justificación: Datos temporales naturalmente ordenados, tabla con potencial de >1M registros
-- Casos de uso: Queries por rangos de fechas amplios
-- Trade-offs:
--   ✅ Tamaño 100x más pequeño que B-tree (típicamente <1 MB vs 50+ MB)
--   ✅ Mantenimiento casi nulo
--   ✅ Ideal para tablas >10M registros
--   ❌ Menos preciso (puede escanear bloques extra)
--   ❌ Requiere que datos estén correlacionados físicamente (CLUSTER o INSERT ordenado)

DROP INDEX IF EXISTS idx_orders_purchase_timestamp_brin CASCADE;

CREATE INDEX idx_orders_purchase_timestamp_brin 
ON orders USING BRIN (order_purchase_timestamp)
WITH (pages_per_range = 128);  -- 128 páginas por rango (1 MB aprox)

COMMENT ON INDEX idx_orders_purchase_timestamp_brin IS 
'Índice BRIN para queries por rango de fechas en orders.
Extremadamente compacto (100x más pequeño que B-tree).
IMPORTANTE: Requiere que orders esté físicamente ordenado por purchase_timestamp.
Ejecutar: CLUSTER orders USING idx_orders_purchase_date; (si existe B-tree en esa columna)
o ALTER TABLE orders CLUSTER ON idx_orders_purchase_timestamp_brin;';

-- Para verificar si tabla está correlacionada:
-- SELECT tablename, attname, correlation 
-- FROM pg_stats 
-- WHERE tablename = 'orders' AND attname = 'order_purchase_timestamp';
-- Valor cercano a 1.0 o -1.0 indica buena correlación (ideal para BRIN)


-- ÍNDICE BRIN #2: Order Items - Order ID (si order_id es secuencial)
-- Tipo: BRIN
-- Justificación: Si order_id tiene correlación temporal, BRIN es eficiente
-- Nota: Solo útil si order_items está físicamente ordenado por order_id

DROP INDEX IF EXISTS idx_order_items_order_id_brin CASCADE;

CREATE INDEX idx_order_items_order_id_brin 
ON order_items USING BRIN (order_id)
WITH (pages_per_range = 64);

COMMENT ON INDEX idx_order_items_order_id_brin IS 
'Índice BRIN experimental en order_items.order_id.
Solo eficiente si order_items está físicamente ordenado por order_id.
Verificar correlación antes de usar en producción.';


-- ========================================
-- SECCIÓN 5: ÍNDICES ESPECIALIZADOS ADICIONALES
-- ========================================

-- ÍNDICE DE EXPRESIÓN #1: Orders - Año y Mes de Purchase
-- Tipo: Índice de Expresión
-- Justificación: Queries frecuentes por mes/año sin necesidad de EXTRACT en WHERE
-- Permite: WHERE date_trunc('month', order_purchase_timestamp) = '2017-01-01'

DROP INDEX IF EXISTS idx_orders_purchase_month CASCADE;

CREATE INDEX idx_orders_purchase_month 
ON orders (date_trunc('month', order_purchase_timestamp));

COMMENT ON INDEX idx_orders_purchase_month IS 
'Índice de expresión para agregaciones por mes.
Permite queries eficientes por mes sin EXTRACT en WHERE.';


-- ÍNDICE DE EXPRESIÓN #2: Order Items - Total (Price + Freight)
-- Tipo: Índice de Expresión
-- Justificación: Queries frecuentes por valor total sin recalcular en WHERE

DROP INDEX IF EXISTS idx_order_items_total_value CASCADE;

CREATE INDEX idx_order_items_total_value 
ON order_items ((price + freight_value) DESC);

COMMENT ON INDEX idx_order_items_total_value IS 
'Índice de expresión para ordenamiento por valor total (price + freight).
Evita recalcular expresión en ORDER BY.';


-- ÍNDICE HASH #1: Customers - Customer Unique ID (solo para igualdad)
-- Tipo: HASH
-- Justificación: Búsquedas exactas por CPF hasheado (solo operador =)
-- Trade-offs:
--   ✅ Más rápido que B-tree para igualdad exacta (10-15%)
--   ✅ Más compacto que B-tree
--   ❌ Solo soporta operador = (no <, >, BETWEEN, LIKE)
--   ❌ No puede usarse para ORDER BY

-- NOTA: HASH es raramente necesario, B-tree suele ser suficiente
-- DESCOMENTAR solo si benchmarks muestran beneficio real

-- DROP INDEX IF EXISTS idx_customers_unique_id_hash CASCADE;
-- 
-- CREATE INDEX idx_customers_unique_id_hash 
-- ON customers USING HASH (customer_unique_id);
-- 
-- COMMENT ON INDEX idx_customers_unique_id_hash IS 
-- 'Índice HASH para búsqueda exacta por CPF hasheado.
-- Ligeramente más rápido que B-tree para operador = exacto.';


-- ========================================
-- SECCIÓN 6: ANÁLISIS Y MANTENIMIENTO
-- ========================================

-- Forzar análisis de estadísticas para todos los índices nuevos
ANALYZE customers;
ANALYZE sellers;
ANALYZE products;
ANALYZE orders;
ANALYZE order_items;
ANALYZE order_payments;
ANALYZE product_category_name_translation;

-- ========================================
-- SECCIÓN 7: CONSULTAS DE VERIFICACIÓN
-- ========================================

-- Verificar tamaño de todos los índices creados
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE indexname LIKE '%advanced%' 
    OR indexname LIKE '%gin%' 
    OR indexname LIKE '%partial%'
    OR indexname LIKE '%brin%'
ORDER BY pg_relation_size(indexrelid) DESC;


-- Verificar índices no utilizados (después de período de prueba)
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelid NOT IN (
        SELECT indexrelid 
        FROM pg_index 
        WHERE indisprimary OR indisunique
    )
ORDER BY pg_relation_size(indexrelid) DESC;


-- Verificar correlación física (para validar índices BRIN)
SELECT 
    tablename,
    attname,
    correlation,
    CASE 
        WHEN ABS(correlation) > 0.9 THEN 'Excelente para BRIN'
        WHEN ABS(correlation) > 0.7 THEN 'Bueno para BRIN'
        WHEN ABS(correlation) > 0.5 THEN 'Aceptable para BRIN'
        ELSE 'No recomendado para BRIN'
    END as brin_suitability
FROM pg_stats
WHERE tablename IN ('orders', 'order_items')
    AND attname IN ('order_purchase_timestamp', 'order_id')
ORDER BY tablename, attname;


-- ========================================
-- RESUMEN DE ÍNDICES ESPECIALIZADOS CREADOS
-- ========================================

/*
TIPO DE ÍNDICE               | CANTIDAD | TABLAS AFECTADAS | TAMAÑO ESTIMADO | CASOS DE USO
-----------------------------|----------|------------------|-----------------|---------------------
B-tree Compuesto Avanzado    | 3        | orders, order_items | ~60 MB    | Queries multi-columna
GIN (JSONB)                  | 3        | products         | ~25 MB         | Búsquedas en JSONB
Índices Parciales            | 4        | orders, order_items, customers | ~30 MB | Subconjuntos frecuentes
BRIN                         | 2        | orders, order_items | ~0.5 MB  | Rangos temporales grandes
Índices de Expresión         | 2        | orders, order_items | ~15 MB   | Cálculos pre-computados
-----------------------------|----------|------------------|-----------------|---------------------
TOTAL                        | 14       | 5 tablas         | ~130 MB        | Optimización completa

MEJORAS DE RENDIMIENTO ESPERADAS:
- Búsquedas JSONB: 85-95% reducción en tiempo
- Queries con índices parciales: 60-70% reducción
- Queries de analytics con BRIN: 40-50% reducción (en tablas grandes)
- Queries multi-columna: 40-60% reducción

TRADE-OFFS GLOBALES:
✅ Mejora drástica en tiempos de query
✅ Cobertura completa de patrones de consulta identificados
❌ +130 MB de espacio en disco
❌ Overhead en escrituras (~15-20% más lento INSERT/UPDATE)
❌ Requiere mantenimiento periódico (REINDEX, ANALYZE)

PRÓXIMOS PASOS:
1. Ejecutar EXPLAIN ANALYZE en consultas optimizadas
2. Comparar antes/después con métricas
3. Monitorear uso con pg_stat_user_indexes
4. Eliminar índices no utilizados después de 30 días
5. Considerar CLUSTER en orders si BRIN es relevante
*/

-- ========================================
-- FIN DEL ARCHIVO - ÍNDICES ESPECIALIZADOS
-- ========================================
