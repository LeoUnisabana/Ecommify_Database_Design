# Ecommify Database Design 🛍️

Diseño de base de datos híbrida (PostgreSQL + MongoDB) para un sistema de e-commerce basado en el dataset de Olist - plataforma brasileña de comercio electrónico.

## 📋 Descripción del Proyecto

Este proyecto implementa un diseño de base de datos robusto y escalable que combina:
- **PostgreSQL**: Para datos estructurados y transaccionales (pedidos, pagos, productos, clientes)
- **MongoDB**: Para datos semi-estructurados (reviews con análisis de sentimientos)

El diseño sigue principios de normalización, integridad referencial y optimización para consultas analíticas y transaccionales.

## 🗂️ Estructura del Proyecto

```
├── docs/                              # Documentación técnica
│   ├── Documento_Tecnico_Diseno.pdf  # Especificaciones técnicas completas
│   └── Presentacion_Ejecutiva.pdf    # Presentación ejecutiva del proyecto
│
├── postgresql/                        # Base de datos relacional
│   ├── schema/
│   │   └── 01_create_types.sql       # Tipos personalizados (ENUMs, Composite Types, Domains)
│   ├── queries/                       # Consultas SQL de análisis
│   └── seed_data/                     # Datos de prueba
│
├── mondodb/                           # Base de datos NoSQL
│   └── schema/
│       └── order_reviews_schema.js   # Schema de reviews con validación y análisis de sentimientos
│
└── notebooks/                         # Análisis de datos
    └── Data_Exploration_Analysis.ipynb
```

## 🎯 Características Principales

### PostgreSQL
- ✅ **Tipos personalizados** (ENUMs): Estados de pedidos, métodos de pago
- ✅ **Tipos compuestos**: Direcciones completas, dimensiones de productos
- ✅ **Dominios**: Validación de códigos postales, precios, scores
- ✅ **Normalización** hasta 3FN para minimizar redundancia
- ✅ **Índices optimizados** para consultas frecuentes

### MongoDB
- ✅ **Schema validation** con JSON Schema estricto
- ✅ **Análisis de sentimientos** (polarity, subjectivity, classification)
- ✅ **Extracción de keywords** y topics de reviews
- ✅ **Documentos embebidos** para información de clientes
- ✅ **Respuestas a reviews** con timestamp y autor

## 🚀 Tecnologías Utilizadas

- **PostgreSQL 14+**: Base de datos relacional
- **MongoDB 6+**: Base de datos de documentos
- **Python/Jupyter**: Análisis exploratorio de datos
- **SQL**: Lenguaje de consultas estructuradas
- **JavaScript/MongoDB Shell**: Scripts de schema y validación

## 📊 Modelo de Datos

### Entidades Principales (PostgreSQL)
- **Customers**: Clientes y sus direcciones
- **Orders**: Pedidos con estados y timestamps
- **Order Items**: Ítems individuales de cada pedido
- **Products**: Catálogo de productos con dimensiones
- **Sellers**: Vendedores de la plataforma
- **Payments**: Transacciones de pago
- **Shipping**: Información de envíos y entregas

### Colecciones (MongoDB)
- **order_reviews**: Reviews de pedidos con análisis de sentimientos automático

## 🛠️ Instalación y Uso

### Requisitos Previos
- PostgreSQL 14 o superior
- MongoDB 6 o superior
- Cliente de PostgreSQL (psql, pgAdmin, DBeaver)
- MongoDB Compass o mongosh

### Configuración PostgreSQL
```bash
# Conectar a PostgreSQL
psql -U postgres

# Crear base de datos
CREATE DATABASE ecommify_db;

# Ejecutar schema de tipos
\i postgresql/schema/01_create_types.sql
```

### Configuración MongoDB
```bash
# Conectar a MongoDB
mongosh

# Ejecutar schema de reviews
load('mondodb/schema/order_reviews_schema.js')
```

## 📈 Análisis de Datos

El notebook [Data_Exploration_Analysis.ipynb](notebooks/Data_Exploration_Analysis.ipynb) contiene:
- Exploración de datos del dataset Olist
- Análisis estadísticos de ventas y reviews
- Visualizaciones de patrones de compra
- Análisis geográfico de clientes y vendedores

## 👥 Autor

**Olist DB Team** 
Leonardo Pérez Ramirez
Ivan Felipe Vera
Juan Felipe Gonzalez 
Fecha de creación: Mayo 2026

## 📄 Licencia

Este proyecto es parte de un trabajo académico de Maestría en Bases de Datos.

## 📚 Documentación Adicional

Para más detalles técnicos, consultar:
- [Documento Técnico de Diseño](docs/Documento_Tecnico_Diseno.pdf)
- [Presentación Ejecutiva](docs/Presentacion_Ejecutiva.pdf)