// ========================================
// ECOMMIFY DATABASE - MONGODB SCHEMA
// products_catalog_schema.js
// ========================================
// Descripción: Colección de productos con catálogo flexible
// Patrón: Documento embebido + atributos dinámicos
// Autor: Olist DB Team
// Fecha: 25 de mayo de 2026
// ========================================

// Seleccionar base de datos
use('olist_ecommerce');

// ========================================
// 1. CREAR COLECCIÓN CON SCHEMA VALIDATION
// ========================================

db.createCollection("products_catalog", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "name", "category", "price"],
      properties: {
        _id: {
          bsonType: "string",
          description: "Product ID (debe coincidir con PostgreSQL product_id)"
        },
        name: {
          bsonType: "string",
          minLength: 1,
          maxLength: 200,
          description: "Nombre del producto"
        },
        description: {
          bsonType: "string",
          description: "Descripción detallada del producto"
        },
        category: {
          bsonType: "object",
          required: ["name_pt", "name_en"],
          properties: {
            name_pt: {
              bsonType: "string",
              description: "Nombre de categoría en portugués"
            },
            name_en: {
              bsonType: "string",
              description: "Nombre de categoría en inglés"
            }
          }
        },
        price: {
          bsonType: "double",
          minimum: 0,
          description: "Precio actual del producto"
        },
        dimensions: {
          bsonType: "object",
          properties: {
            weight_g: { bsonType: "int", minimum: 1 },
            length_cm: { bsonType: "int", minimum: 1 },
            height_cm: { bsonType: "int", minimum: 1 },
            width_cm: { bsonType: "int", minimum: 1 }
          }
        },
        images: {
          bsonType: "array",
          items: { bsonType: "string" },
          description: "URLs de imágenes del producto"
        },
        attributes: {
          bsonType: "object",
          description: "Atributos dinámicos según categoría (voltage, size, color, etc.)"
        },
        ratings: {
          bsonType: "object",
          properties: {
            avg_score: { bsonType: "double", minimum: 1, maximum: 5 },
            total_reviews: { bsonType: "int", minimum: 0 },
            distribution: { bsonType: "object" }
          }
        },
        availability: {
          bsonType: "object",
          properties: {
            in_stock: { bsonType: "bool" },
            stock_quantity: { bsonType: "int", minimum: 0 },
            sellers: { bsonType: "array" }
          }
        },
        metadata: {
          bsonType: "object",
          properties: {
            created_at: { bsonType: "date" },
            updated_at: { bsonType: "date" },
            views_count: { bsonType: "int" },
            sales_count: { bsonType: "int" }
          }
        }
      }
    }
  },
  validationLevel: "moderate",  // Solo nuevos inserts/updates
  validationAction: "warn"       // Solo advertir, no bloquear
});

// ========================================
// 2. CREAR ÍNDICES
// ========================================

// Índice único para product_id
db.products_catalog.createIndex({ "_id": 1 }, { unique: true });

// Índice compuesto para búsquedas por categoría y precio
db.products_catalog.createIndex(
  { "category.name_en": 1, "price": 1 },
  { name: "idx_category_price" }
);

// Índice para ranking de productos
db.products_catalog.createIndex(
  { "ratings.avg_score": -1, "ratings.total_reviews": -1 },
  { name: "idx_ratings" }
);

// Índice text search para nombre y descripción
db.products_catalog.createIndex(
  { "name": "text", "description": "text" },
  {
    name: "idx_text_search",
    weights: { name: 10, description: 5 },
    default_language: "portuguese"
  }
);

// Índice para filtrar disponibles
db.products_catalog.createIndex(
  { "availability.in_stock": 1 },
  { name: "idx_in_stock" }
);

// Índice para ordenar por popularidad
db.products_catalog.createIndex(
  { "metadata.sales_count": -1 },
  { name: "idx_sales_count" }
);

// ========================================
// 3. INSERTAR DOCUMENTO DE EJEMPLO
// ========================================

db.products_catalog.insertOne({
  "_id": "prod_electronics_001",
  "name": "Mouse Logitech MX Master 3",
  "description": "Mouse ergonômico sem fio com 7 botões programáveis e tecnologia Darkfield. Ideal para produtividade.",
  "category": {
    "name_pt": "informatica_acessorios",
    "name_en": "computers_accessories"
  },
  "price": 89.90,
  "dimensions": {
    "weight_g": 141,
    "length_cm": 12,
    "height_cm": 5,
    "width_cm": 8
  },
  "images": [
    "https://cdn.olist.com/prod_001_main.jpg",
    "https://cdn.olist.com/prod_001_side.jpg",
    "https://cdn.olist.com/prod_001_box.jpg"
  ],
  "attributes": {
    "voltage": "USB (não requer voltagem)",
    "wireless": true,
    "battery_life_hours": 70,
    "dpi": [400, 800, 1600, 3200],
    "warranty_months": 12,
    "brand": "Logitech",
    "model": "MX Master 3",
    "color": "Graphite"
  },
  "ratings": {
    "avg_score": 4.7,
    "total_reviews": 234,
    "distribution": {
      "5_stars": 180,
      "4_stars": 40,
      "3_stars": 10,
      "2_stars": 3,
      "1_star": 1
    }
  },
  "availability": {
    "in_stock": true,
    "stock_quantity": 150,
    "sellers": [
      {
        "seller_id": "seller_sp_001",
        "seller_name": "Tech Store São Paulo",
        "price": 89.90,
        "stock": 50,
        "shipping_estimate_days": 2
      },
      {
        "seller_id": "seller_rj_002",
        "seller_name": "Electronics Rio",
        "price": 92.00,
        "stock": 100,
        "shipping_estimate_days": 3
      }
    ]
  },
  "metadata": {
    "created_at": new Date("2026-01-15T10:30:00Z"),
    "updated_at": new Date("2026-05-20T14:22:10Z"),
    "views_count": 12456,
    "sales_count": 234,
    "synced_from_postgres_at": new Date()
  }
});

// ========================================
// 4. QUERIES DE EJEMPLO
// ========================================

// Query 1: Buscar productos por categoría
print("\\n=== Query 1: Productos de electrónica ===");
db.products_catalog.find(
  { "category.name_en": "computers_accessories" },
  { name: 1, price: 1, "ratings.avg_score": 1 }
).sort({ "ratings.avg_score": -1 }).limit(5).pretty();

// Query 2: Búsqueda por texto
print("\\n=== Query 2: Búsqueda de texto ===");
db.products_catalog.find(
  { $text: { $search: "mouse wireless" } },
  { score: { $meta: "textScore" }, name: 1, price: 1 }
).sort({ score: { $meta: "textScore" } }).limit(5).pretty();

// Query 3: Filtrar por precio y stock
print("\\n=== Query 3: Productos disponibles < R$100 ===");
db.products_catalog.find(
  { 
    "price": { $lt: 100 },
    "availability.in_stock": true 
  },
  { name: 1, price: 1, "availability.stock_quantity": 1 }
).limit(5).pretty();

// Query 4: Agregación - Top 5 productos más vendidos
print("\\n=== Query 4: Top 5 productos más vendidos ===");
db.products_catalog.aggregate([
  { $match: { "metadata.sales_count": { $gt: 0 } } },
  { $sort: { "metadata.sales_count": -1 } },
  { $limit: 5 },
  {
    $project: {
      _id: 0,
      name: 1,
      sales_count: "$metadata.sales_count",
      avg_rating: "$ratings.avg_score",
      price: 1
    }
  }
]).pretty();

// ========================================
// 5. RESUMEN
// ========================================

print("\\n========================================");
print("COLECCIÓN products_catalog CREADA");
print("========================================");
print("Validación de schema: Habilitada (moderate)");
print("Índices creados: 6");
print("  - _id (unique)");
print("  - category + price (compound)");
print("  - ratings (sorting)");
print("  - text search (name + description)");
print("  - in_stock (filtering)");
print("  - sales_count (popularity)");
print("\\nDocumento de ejemplo insertado: prod_electronics_001");
print("========================================");
