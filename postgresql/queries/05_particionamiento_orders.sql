-- ========================================
-- ECOMMIFY DATABASE - PARTICIONAMIENTO DECLARATIVO
-- 05_particionamiento_orders.sql
-- ========================================
-- Descripción: Implementación de particionamiento RANGE en tabla Orders
-- Propósito: Mejorar rendimiento de queries por fecha y facilitar mantenimiento
-- Autor: Olist DB Team - Unidad 4
-- Fecha: 9 de junio de 2026
-- ========================================

-- ========================================
-- ANÁLISIS Y JUSTIFICACIÓN
-- ========================================

/*
TABLA SELECCIONADA: orders
- Registros actuales: ~99,441
- Columna de partición: order_purchase_timestamp
- Tipo de particionamiento: RANGE (por mes)
- Granularidad: Mensual

JUSTIFICACIÓN:
✅ Volumen cercano a 100K (umbral recomendado)
✅ Queries frecuentes filtran por rangos de fecha
✅ Patrón de crecimiento continuo (datos nuevos diarios)
✅ Necesidad de archivado de datos antiguos (retención 2-3 años)
✅ Partition pruning automático reducirá scan en 60-80%

ALTERNATIVAS DESCARTADAS:
❌ order_items: Requeriría particionamiento indirecto (por order_id -> fecha)
❌ customers: Sin patrón temporal claro
❌ products: Datos maestros (no transaccionales)

GRANULARIDAD: Mensual
✅ ~8,000 pedidos/mes (tamaño manejable)
✅ Balance entre número de particiones y eficiencia
✅ Queries típicas son por mes/trimestre
❌ Descartado semanal: Demasiadas particiones (50+/año)
❌ Descartado anual: Particiones muy grandes (100K+)

BENEFICIOS ESPERADOS:
- Partition pruning: 60-80% reducción en queries por fecha
- Índices más pequeños por partición: 50-70% más rápidos
- VACUUM/ANALYZE más eficiente
- Archivado simplificado (DROP/DETACH partición antigua)
*/

-- ========================================
-- PASO 1: BACKUP DE DATOS EXISTENTES
-- ========================================

-- IMPORTANTE: Crear backup ANTES de migrar a particionamiento
CREATE TABLE orders_backup AS SELECT * FROM orders;

COMMENT ON TABLE orders_backup IS 
'Backup de tabla orders antes de conversión a particionamiento.
Creado: 2026-06-09. Eliminar después de validación exitosa.';

-- Verificar backup
SELECT COUNT(*) as total_orders_backup FROM orders_backup;


-- ========================================
-- PASO 2: RENOMBRAR TABLA ORIGINAL
-- ========================================

-- Renombrar tabla original para preservar datos
ALTER TABLE orders RENAME TO orders_old;

-- Renombrar constraints para evitar conflictos
ALTER INDEX orders_pkey RENAME TO orders_old_pkey;
-- Renombrar otros índices existentes (ajustar según necesidad)
-- ALTER INDEX idx_orders_customer RENAME TO idx_orders_old_customer;


-- ========================================
-- PASO 3: CREAR TABLA PARTICIONADA
-- ========================================

-- Crear nueva tabla orders con particionamiento RANGE
CREATE TABLE orders (
    order_id VARCHAR(32),
    customer_id VARCHAR(32) NOT NULL,
    order_status order_status_type NOT NULL DEFAULT 'created',
    order_purchase_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_approved_at TIMESTAMP WITHOUT TIME ZONE,
    order_delivered_carrier_date TIMESTAMP WITHOUT TIME ZONE,
    order_delivered_customer_date TIMESTAMP WITHOUT TIME ZONE,
    order_estimated_delivery_date TIMESTAMP WITHOUT TIME ZONE,
    
    -- PRIMARY KEY debe incluir columna de partición
    PRIMARY KEY (order_id, order_purchase_timestamp),
    
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
) PARTITION BY RANGE (order_purchase_timestamp);

COMMENT ON TABLE orders IS 
'Pedidos del marketplace - TABLA PARTICIONADA POR RANGO (mensual).
Columna de partición: order_purchase_timestamp.
Estrategia: Una partición por mes para optimizar queries por período.';


-- ========================================
-- PASO 4: CREAR PARTICIONES MENSUALES
-- ========================================

-- NOTA: El dataset Olist contiene datos de 2016-09 a 2018-10
-- Crear particiones para este rango + buffer futuro

-- Particiones 2016
CREATE TABLE orders_2016_09 PARTITION OF orders
    FOR VALUES FROM ('2016-09-01') TO ('2016-10-01');

CREATE TABLE orders_2016_10 PARTITION OF orders
    FOR VALUES FROM ('2016-10-01') TO ('2016-11-01');

CREATE TABLE orders_2016_11 PARTITION OF orders
    FOR VALUES FROM ('2016-11-01') TO ('2016-12-01');

CREATE TABLE orders_2016_12 PARTITION OF orders
    FOR VALUES FROM ('2016-12-01') TO ('2017-01-01');

-- Particiones 2017 (año completo)
CREATE TABLE orders_2017_01 PARTITION OF orders
    FOR VALUES FROM ('2017-01-01') TO ('2017-02-01');

CREATE TABLE orders_2017_02 PARTITION OF orders
    FOR VALUES FROM ('2017-02-01') TO ('2017-03-01');

CREATE TABLE orders_2017_03 PARTITION OF orders
    FOR VALUES FROM ('2017-03-01') TO ('2017-04-01');

CREATE TABLE orders_2017_04 PARTITION OF orders
    FOR VALUES FROM ('2017-04-01') TO ('2017-05-01');

CREATE TABLE orders_2017_05 PARTITION OF orders
    FOR VALUES FROM ('2017-05-01') TO ('2017-06-01');

CREATE TABLE orders_2017_06 PARTITION OF orders
    FOR VALUES FROM ('2017-06-01') TO ('2017-07-01');

CREATE TABLE orders_2017_07 PARTITION OF orders
    FOR VALUES FROM ('2017-07-01') TO ('2017-08-01');

CREATE TABLE orders_2017_08 PARTITION OF orders
    FOR VALUES FROM ('2017-08-01') TO ('2017-09-01');

CREATE TABLE orders_2017_09 PARTITION OF orders
    FOR VALUES FROM ('2017-09-01') TO ('2017-10-01');

CREATE TABLE orders_2017_10 PARTITION OF orders
    FOR VALUES FROM ('2017-10-01') TO ('2017-11-01');

CREATE TABLE orders_2017_11 PARTITION OF orders
    FOR VALUES FROM ('2017-11-01') TO ('2017-12-01');

CREATE TABLE orders_2017_12 PARTITION OF orders
    FOR VALUES FROM ('2017-12-01') TO ('2018-01-01');

-- Particiones 2018
CREATE TABLE orders_2018_01 PARTITION OF orders
    FOR VALUES FROM ('2018-01-01') TO ('2018-02-01');

CREATE TABLE orders_2018_02 PARTITION OF orders
    FOR VALUES FROM ('2018-02-01') TO ('2018-03-01');

CREATE TABLE orders_2018_03 PARTITION OF orders
    FOR VALUES FROM ('2018-03-01') TO ('2018-04-01');

CREATE TABLE orders_2018_04 PARTITION OF orders
    FOR VALUES FROM ('2018-04-01') TO ('2018-05-01');

CREATE TABLE orders_2018_05 PARTITION OF orders
    FOR VALUES FROM ('2018-05-01') TO ('2018-06-01');

CREATE TABLE orders_2018_06 PARTITION OF orders
    FOR VALUES FROM ('2018-06-01') TO ('2018-07-01');

CREATE TABLE orders_2018_07 PARTITION OF orders
    FOR VALUES FROM ('2018-07-01') TO ('2018-08-01');

CREATE TABLE orders_2018_08 PARTITION OF orders
    FOR VALUES FROM ('2018-08-01') TO ('2018-09-01');

CREATE TABLE orders_2018_09 PARTITION OF orders
    FOR VALUES FROM ('2018-09-01') TO ('2018-10-01');

CREATE TABLE orders_2018_10 PARTITION OF orders
    FOR VALUES FROM ('2018-10-01') TO ('2018-11-01');

-- Particiones futuras (buffer para crecimiento)
CREATE TABLE orders_2018_11 PARTITION OF orders
    FOR VALUES FROM ('2018-11-01') TO ('2018-12-01');

CREATE TABLE orders_2018_12 PARTITION OF orders
    FOR VALUES FROM ('2018-12-01') TO ('2019-01-01');

CREATE TABLE orders_2019_01 PARTITION OF orders
    FOR VALUES FROM ('2019-01-01') TO ('2019-02-01');

CREATE TABLE orders_2019_02 PARTITION OF orders
    FOR VALUES FROM ('2019-02-01') TO ('2019-03-01');

-- Partición DEFAULT para datos fuera de rango
CREATE TABLE orders_default PARTITION OF orders DEFAULT;

COMMENT ON TABLE orders_default IS 
'Partición por defecto para pedidos fuera de rango definido.
Monitorear esta partición: si crece, crear particiones específicas.';


-- ========================================
-- PASO 5: MIGRAR DATOS DE TABLA ANTIGUA
-- ========================================

-- Insertar datos de tabla antigua a particionada
-- PostgreSQL automáticamente distribuirá en particiones correctas
INSERT INTO orders 
SELECT * FROM orders_old;

-- Verificar migración exitosa
SELECT 
    COUNT(*) as orders_old_count,
    (SELECT COUNT(*) FROM orders) as orders_partitioned_count,
    CASE 
        WHEN COUNT(*) = (SELECT COUNT(*) FROM orders) THEN '✅ Migración exitosa'
        ELSE '❌ Error: conteos no coinciden'
    END as migration_status
FROM orders_old;


-- ========================================
-- PASO 6: CREAR ÍNDICES EN TABLA PARTICIONADA
-- ========================================

-- Los índices se crean en la tabla padre y se propagan automáticamente a particiones

-- Índice en customer_id (FK, queries frecuentes)
CREATE INDEX idx_orders_customer ON orders(customer_id);

-- Índice en order_status
CREATE INDEX idx_orders_status ON orders(order_status);

-- Índice compuesto para dashboard
CREATE INDEX idx_orders_customer_status_date 
ON orders(customer_id, order_status, order_purchase_timestamp DESC);

-- Índice parcial: solo pedidos entregados
CREATE INDEX idx_orders_delivered 
ON orders(order_purchase_timestamp DESC) 
WHERE order_status = 'delivered';

-- NOTA: PostgreSQL creará automáticamente índices individuales en cada partición:
-- - orders_2017_01_customer_id_idx
-- - orders_2017_02_customer_id_idx
-- - etc.

-- Forzar ANALYZE para actualizar estadísticas
ANALYZE orders;


-- ========================================
-- PASO 7: RECREAR FOREIGN KEYS DEPENDIENTES
-- ========================================

-- Las tablas que referencian orders (order_items, order_payments) 
-- deben actualizar sus FKs

-- Eliminar FK antigua en order_items
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS fk_items_order CASCADE;

-- Crear nueva FK a tabla particionada
ALTER TABLE order_items 
ADD CONSTRAINT fk_items_order 
FOREIGN KEY (order_id) 
REFERENCES orders(order_id)
ON DELETE CASCADE;

-- Eliminar FK antigua en order_payments
ALTER TABLE order_payments DROP CONSTRAINT IF EXISTS fk_payments_order CASCADE;

-- Crear nueva FK a tabla particionada
ALTER TABLE order_payments 
ADD CONSTRAINT fk_payments_order 
FOREIGN KEY (order_id) 
REFERENCES orders(order_id)
ON DELETE CASCADE;

COMMENT ON CONSTRAINT fk_items_order ON order_items IS 
'FK a tabla orders particionada. Actualizado en U4 - particionamiento.';


-- ========================================
-- PASO 8: VALIDACIÓN Y PRUEBAS
-- ========================================

-- Verificar distribución de datos por partición
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    (SELECT COUNT(*) FROM orders WHERE order_purchase_timestamp >= 
        CASE 
            WHEN tablename = 'orders_2017_01' THEN '2017-01-01'::timestamp
            WHEN tablename = 'orders_2017_02' THEN '2017-02-01'::timestamp
            -- ... agregar más casos según necesidad
            ELSE '1900-01-01'::timestamp
        END
        AND order_purchase_timestamp < 
        CASE 
            WHEN tablename = 'orders_2017_01' THEN '2017-02-01'::timestamp
            WHEN tablename = 'orders_2017_02' THEN '2017-03-01'::timestamp
            ELSE '2100-01-01'::timestamp
        END
    ) as row_count
FROM pg_tables
WHERE tablename LIKE 'orders_20%'
ORDER BY tablename;

-- Alternativa: Usar pg_stat para contar filas
SELECT 
    schemaname,
    tablename,
    n_live_tup as estimated_rows,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_stat_user_tables
WHERE tablename LIKE 'orders_%'
ORDER BY tablename;


-- ========================================
-- PASO 9: PRUEBAS DE PARTITION PRUNING
-- ========================================

-- Test 1: Query con rango de fechas específico (debe usar solo 1-2 particiones)
EXPLAIN (ANALYZE, BUFFERS) 
SELECT COUNT(*), AVG(order_delivered_customer_date - order_purchase_timestamp) as avg_delivery_time
FROM orders
WHERE order_purchase_timestamp >= '2017-06-01'
    AND order_purchase_timestamp < '2017-07-01'
    AND order_status = 'delivered';

-- Verificar en el plan: "Partitions pruned: XX" o lista de particiones escaneadas
-- Esperado: Solo orders_2017_06 debería ser escaneada


-- Test 2: Query sin filtro de fecha (debe escanear todas las particiones)
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_status, COUNT(*)
FROM orders
GROUP BY order_status;

-- Esperado: Parallel Seq Scan en todas las particiones


-- Test 3: Query con fecha exacta (debe usar 1 partición)
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders
WHERE order_id = 'SPECIFIC_ORDER_ID'
    AND order_purchase_timestamp >= '2017-05-01'  -- Hint para partition pruning
    AND order_purchase_timestamp < '2017-06-01';

-- Esperado: Index Scan en una sola partición


-- ========================================
-- PASO 10: FUNCIÓN DE CREACIÓN AUTOMÁTICA DE PARTICIONES
-- ========================================

-- Función para crear partición del mes siguiente automáticamente
CREATE OR REPLACE FUNCTION create_next_month_partition()
RETURNS TEXT AS $$
DECLARE
    next_month DATE := date_trunc('month', NOW() + INTERVAL '2 months')::DATE;
    next_month_end DATE := next_month + INTERVAL '1 month';
    partition_name TEXT := 'orders_' || to_char(next_month, 'YYYY_MM');
    partition_exists BOOLEAN;
BEGIN
    -- Verificar si partición ya existe
    SELECT EXISTS (
        SELECT 1 FROM pg_class WHERE relname = partition_name
    ) INTO partition_exists;
    
    IF partition_exists THEN
        RETURN 'Partición ' || partition_name || ' ya existe';
    END IF;
    
    -- Crear partición
    EXECUTE format(
        'CREATE TABLE %I PARTITION OF orders FOR VALUES FROM (%L) TO (%L)',
        partition_name,
        next_month,
        next_month_end
    );
    
    RETURN 'Partición ' || partition_name || ' creada exitosamente para período ' || 
           next_month || ' a ' || next_month_end;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_next_month_partition() IS 
'Crea automáticamente la partición para el mes siguiente.
Ejecutar mensualmente vía pg_cron o cron del sistema.';

-- Probar función
SELECT create_next_month_partition();


-- ========================================
-- PASO 11: CONFIGURAR CREACIÓN AUTOMÁTICA (OPCIONAL)
-- ========================================

-- OPCIÓN 1: Usar pg_cron extension (si está disponible)
/*
-- Instalar extension (requiere permisos de superusuario)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Programar ejecución mensual (día 1 de cada mes a las 00:00)
SELECT cron.schedule(
    'create-monthly-partition',
    '0 0 1 * *',  -- Cron expression: minuto hora día mes día_semana
    'SELECT create_next_month_partition()'
);

-- Verificar tareas programadas
SELECT * FROM cron.job;
*/

-- OPCIÓN 2: Script Python/Bash con cron del sistema
-- Ver archivo: scripts/create_partition_cron.sh


-- ========================================
-- PASO 12: ESTRATEGIA DE ARCHIVADO
-- ========================================

-- Procedimiento para archivar particiones antiguas (>2 años)

/*
ESTRATEGIA DE RETENCIÓN:
- Mes 1-12: Activo (queries frecuentes)
- Mes 13-24: Activo (queries ocasionales)
- Mes 25-36: Archivo en tabla separada (queries raras)
- Mes 37+: Eliminar o exportar a almacenamiento frío (S3, CSV)
*/

-- Función de archivado
CREATE OR REPLACE FUNCTION archive_old_partition(partition_month DATE)
RETURNS TEXT AS $$
DECLARE
    partition_name TEXT := 'orders_' || to_char(partition_month, 'YYYY_MM');
    archive_table TEXT := 'orders_archive_' || to_char(partition_month, 'YYYY_MM');
BEGIN
    -- Verificar antigüedad (>36 meses)
    IF partition_month > NOW() - INTERVAL '36 months' THEN
        RETURN 'Error: Partición ' || partition_name || ' es demasiado reciente para archivar';
    END IF;
    
    -- DETACH partición de tabla padre
    EXECUTE format('ALTER TABLE orders DETACH PARTITION %I', partition_name);
    
    -- Renombrar a tabla de archivo
    EXECUTE format('ALTER TABLE %I RENAME TO %I', partition_name, archive_table);
    
    -- Opcional: Mover a tablespace de almacenamiento frío
    -- EXECUTE format('ALTER TABLE %I SET TABLESPACE cold_storage', archive_table);
    
    RETURN 'Partición ' || partition_name || ' archivada como ' || archive_table;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION archive_old_partition(DATE) IS 
'Desacopla y archiva partición antigua (>36 meses).
Ejemplo de uso: SELECT archive_old_partition(''2017-01-01'');';


-- Función de eliminación de particiones muy antiguas
CREATE OR REPLACE FUNCTION drop_archived_partition(partition_month DATE)
RETURNS TEXT AS $$
DECLARE
    archive_table TEXT := 'orders_archive_' || to_char(partition_month, 'YYYY_MM');
BEGIN
    -- Verificar que tabla existe
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = archive_table) THEN
        RETURN 'Error: Tabla de archivo ' || archive_table || ' no existe';
    END IF;
    
    -- Eliminar tabla de archivo
    EXECUTE format('DROP TABLE %I', archive_table);
    
    RETURN 'Tabla de archivo ' || archive_table || ' eliminada permanentemente';
END;
$$ LANGUAGE plpgsql;


-- ========================================
-- PASO 13: LIMPIEZA (OPCIONAL)
-- ========================================

-- Después de validar que todo funciona correctamente:

-- Eliminar tabla antigua (CUIDADO: irreversible)
-- DROP TABLE orders_old CASCADE;

-- Eliminar backup (después de período de validación)
-- DROP TABLE orders_backup;


-- ========================================
-- RESUMEN Y MÉTRICAS
-- ========================================

/*
IMPLEMENTACIÓN COMPLETADA:
✅ Tabla orders convertida a particionamiento RANGE
✅ 30 particiones creadas (2016-09 a 2019-02)
✅ Partición DEFAULT para datos fuera de rango
✅ Índices propagados a todas las particiones
✅ FKs actualizadas en tablas dependientes
✅ Función de creación automática de particiones
✅ Estrategia de archivado definida

DISTRIBUCIÓN DE DATOS (estimado):
- 2016: 4 particiones (~5,000 pedidos)
- 2017: 12 particiones (~60,000 pedidos)
- 2018: 10 particiones (~35,000 pedidos)
- Promedio: ~3,300 pedidos/partición

MEJORAS DE RENDIMIENTO ESPERADAS:
- Queries por mes específico: 60-80% más rápidas (partition pruning)
- Queries por trimestre: 50-70% más rápidas
- Índices por partición: 70% más pequeños → búsquedas 40-60% más rápidas
- VACUUM/ANALYZE: 90% más rápido (por partición)

QUERIES QUE SE BENEFICIAN:
✅ WHERE order_purchase_timestamp BETWEEN X AND Y
✅ WHERE EXTRACT(MONTH FROM order_purchase_timestamp) = X
✅ WHERE order_purchase_timestamp >= '2017-01-01' AND order_purchase_timestamp < '2017-02-01'

QUERIES QUE NO SE BENEFICIAN:
❌ SELECT * FROM orders WHERE order_status = 'delivered' (sin filtro de fecha)
❌ SELECT * FROM orders WHERE customer_id = X (sin filtro de fecha)
   Nota: Agregar hint de fecha si se conoce: AND order_purchase_timestamp >= '2017-01-01'

MANTENIMIENTO:
- Ejecutar create_next_month_partition() mensualmente
- Monitorear orders_default (debe estar vacía)
- Archivar particiones >36 meses anualmente
- Ejecutar ANALYZE orders después de carga masiva de datos

PRÓXIMOS PASOS:
1. Ejecutar pruebas de rendimiento (ver 06_validacion_metricas.sql)
2. Comparar tiempos de query antes/después
3. Monitorear uso de disco por partición
4. Documentar mejoras en reporte final
*/

-- ========================================
-- FIN DEL ARCHIVO - PARTICIONAMIENTO
-- ========================================
