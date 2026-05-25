-- ========================================
-- ECOMMIFY DATABASE - POSTGRESQL SCHEMA
-- 01_create_types.sql
-- ========================================
-- Descripción: Tipos personalizados (ENUMs, Composite Types)
-- Autor: Olist DB Team
-- Fecha: 25 de mayo de 2026
-- ========================================

-- ========================================
-- 1. TIPOS ENUMERADOS (ENUM)
-- ========================================

-- Estado de los pedidos
CREATE TYPE order_status_type AS ENUM (
    'created',      -- Pedido creado, pendiente de pago
    'approved',     -- Pago aprobado, pendiente procesamiento
    'processing',   -- En preparación por el seller
    'invoiced',     -- Facturado, listo para envío
    'shipped',      -- Enviado al transportista
    'delivered',    -- Entregado al cliente ✅
    'canceled',     -- Cancelado por cliente o seller
    'unavailable'   -- Producto no disponible
);

COMMENT ON TYPE order_status_type IS 'Estados posibles de un pedido (8 estados en ciclo de vida)';

-- Métodos de pago
CREATE TYPE payment_type_enum AS ENUM (
    'credit_card',  -- Tarjeta de crédito
    'boleto',       -- Boleto bancario (específico de Brasil)
    'voucher',      -- Cupón o vale de descuento
    'debit_card',   -- Tarjeta de débito
    'not_defined'   -- No especificado
);

COMMENT ON TYPE payment_type_enum IS 'Métodos de pago soportados en la plataforma';

-- ========================================
-- 2. TIPOS COMPUESTOS (COMPOSITE TYPES)
-- ========================================

-- Tipo para direcciones completas
CREATE TYPE address_type AS (
    street VARCHAR(100),        -- Nombre de la calle
    number VARCHAR(10),          -- Número del domicilio
    complement VARCHAR(50),      -- Complemento (Apto, Sala, etc.)
    neighborhood VARCHAR(50),    -- Barrio/Colonia
    city VARCHAR(50),            -- Ciudad
    state CHAR(2),               -- Estado (sigla de 2 letras)
    zip_code VARCHAR(10)         -- Código postal (CEP en Brasil)
);

COMMENT ON TYPE address_type IS 'Tipo compuesto para almacenar dirección completa de forma estructurada';

-- Tipo para dimensiones de productos
CREATE TYPE dimensions_type AS (
    weight_g INT,    -- Peso en gramos
    length_cm INT,   -- Largo en centímetros
    height_cm INT,   -- Alto en centímetros
    width_cm INT     -- Ancho en centímetros
);

COMMENT ON TYPE dimensions_type IS 'Dimensiones físicas del producto para cálculo de flete';

-- ========================================
-- 3. DOMINIOS (DOMAIN)
-- ========================================

-- Dominio para códigos postales brasileños (5 dígitos)
CREATE DOMAIN brazilian_zip_code AS VARCHAR(10)
    CHECK (VALUE ~ '^\d{5}$');

COMMENT ON DOMAIN brazilian_zip_code IS 'Código postal brasileño (CEP): 5 dígitos';

-- Dominio para siglas de estados brasileños
CREATE DOMAIN brazilian_state_code AS CHAR(2)
    CHECK (VALUE ~ '^[A-Z]{2}$');

COMMENT ON DOMAIN brazilian_state_code IS 'Sigla de estado brasileño (2 letras mayúsculas): SP, RJ, MG, etc.';

-- Dominio para precios (siempre positivos)
CREATE DOMAIN positive_price AS NUMERIC(10,2)
    CHECK (VALUE >= 0);

COMMENT ON DOMAIN positive_price IS 'Precio monetario siempre >= 0';

-- Dominio para scores de review (1-5)
CREATE DOMAIN review_score_type AS INT
    CHECK (VALUE BETWEEN 1 AND 5);

COMMENT ON DOMAIN review_score_type IS 'Puntuación de review: 1(pésimo) a 5(excelente)';

-- ========================================
-- 4. VERIFICACIÓN DE TIPOS CREADOS
-- ========================================

-- Listar todos los tipos personalizados creados
DO $$
BEGIN
    RAISE NOTICE 'Tipos personalizados creados exitosamente:';
    RAISE NOTICE '  - order_status_type (ENUM con 8 estados)';
    RAISE NOTICE '  - payment_type_enum (ENUM con 5 métodos)';
    RAISE NOTICE '  - address_type (COMPOSITE TYPE)';
    RAISE NOTICE '  - dimensions_type (COMPOSITE TYPE)';
    RAISE NOTICE '  - brazilian_zip_code (DOMAIN)';
    RAISE NOTICE '  - brazilian_state_code (DOMAIN)';
    RAISE NOTICE '  - positive_price (DOMAIN)';
    RAISE NOTICE '  - review_score_type (DOMAIN)';
END $$;
