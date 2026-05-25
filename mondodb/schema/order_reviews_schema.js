// ========================================
// ECOMMIFY DATABASE - MONGODB SCHEMA
// order_reviews_schema.js
// ========================================
// Descripción: Colección de reviews con análisis de sentimiento
// Patrón: Documento completo (texto libre)
// Autor: Olist DB Team
// Fecha: 25 de mayo de 2026
// ========================================

use('olist_ecommerce');

// ========================================
// 1. CREAR COLECCIÓN CON SCHEMA VALIDATION
// ========================================

db.createCollection("order_reviews", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "order_id", "review"],
      properties: {
        _id: {
          bsonType: "string",
          description: "Review ID único"
        },
        order_id: {
          bsonType: "string",
          description: "Order ID asociado (debe ser único)"
        },
        customer: {
          bsonType: "object",
          properties: {
            customer_id: { bsonType: "string" },
            customer_city: { bsonType: "string" },
            customer_state: { bsonType: "string" }
          }
        },
        review: {
          bsonType: "object",
          required: ["score", "created_at"],
          properties: {
            score: {
              bsonType: "int",
              minimum: 1,
              maximum: 5,
              description: "Puntuación 1-5 estrellas"
            },
            title: {
              bsonType: "string",
              maxLength: 100,
              description: "Título del comentario"
            },
            message: {
              bsonType: "string",
              description: "Mensaje completo del review"
            },
            created_at: {
              bsonType: "date",
              description: "Fecha de creación"
            },
            answer: {
              bsonType: "object",
              properties: {
                message: { bsonType: "string" },
                answered_at: { bsonType: "date" },
                answered_by: { bsonType: "string" }
              }
            }
          }
        },
        sentiment_analysis: {
          bsonType: "object",
          properties: {
            polarity: {
              bsonType: "double",
              minimum: -1,
              maximum: 1,
              description: "-1 (muy negativo) a +1 (muy positivo)"
            },
            subjectivity: {
              bsonType: "double",
              minimum: 0,
              maximum: 1,
              description: "0 (objetivo) a 1 (subjetivo)"
            },
            classification: {
              enum: ["very_negative", "negative", "neutral", "positive", "very_positive"],
              description: "Clasificación categórica del sentimiento"
            },
            keywords: {
              bsonType: "array",
              items: { bsonType: "string" },
              description: "Palabras clave extraídas"
            },
            topics: {
              bsonType: "array",
              items: { bsonType: "string" },
              description: "Topics identificados (product_quality, delivery_speed, etc.)"
            },
            model_version: {
              bsonType: "string",
              description: "Versión del modelo ML usado"
            },
            analyzed_at: {
              bsonType: "date"
            }
          }
        },
        helpful_votes: {
          bsonType: "int",
          minimum: 0,
          description: "Votos de '¿Te fue útil esta opinión?'"
        },
        metadata: {
          bsonType: "object",
          properties: {
            synced_from_postgres_at: { bsonType: "date" }
          }
        }
      }
    }
  },
  validationLevel: "moderate",
  validationAction: "warn"
});

// ========================================
// 2. CREAR ÍNDICES
// ========================================

// Índice único para order_id (1 review por pedido)
db.order_reviews.createIndex(
  { "order_id": 1 },
  { unique: true, name: "idx_order_id_unique" }
);

// Índice compuesto para filtros de dashboard
db.order_reviews.createIndex(
  { "review.score": 1, "review.created_at": -1 },
  { name: "idx_score_date" }
);

// Índice text search para comentarios
db.order_reviews.createIndex(
  { "review.title": "text", "review.message": "text" },
  {
    name: "idx_review_text_search",
    default_language: "portuguese",
    weights: { "review.title": 10, "review.message": 5 }
  }
);

// Índice para análisis de sentimiento
db.order_reviews.createIndex(
  { "sentiment_analysis.classification": 1 },
  { name: "idx_sentiment_class" }
);

// Índice para customer
db.order_reviews.createIndex(
  { "customer.customer_id": 1 },
  { name: "idx_customer_id" }
);

// Índice para ordenar por helpful votes
db.order_reviews.createIndex(
  { "helpful_votes": -1 },
  { name: "idx_helpful_votes" }
);

// ========================================
// 3. INSERTAR DOCUMENTOS DE EJEMPLO
// ========================================

// Review positiva
db.order_reviews.insertOne({
  "_id": "review_001",
  "order_id": "order_xyz789",
  "customer": {
    "customer_id": "cust_001",
    "customer_city": "São Paulo",
    "customer_state": "SP"
  },
  "review": {
    "score": 5,
    "title": "Excelente produto!",
    "message": "Produto de ótima qualidade. Embalagem perfeita, chegou antes do prazo. Vendedor atencioso. Recomendo 100%!",
    "created_at": new Date("2026-05-10T10:30:00Z"),
    "answer": {
      "message": "Muito obrigado pelo feedback! Ficamos felizes que tenha gostado.",
      "answered_at": new Date("2026-05-11T09:15:00Z"),
      "answered_by": "seller_sp_001"
    }
  },
  "sentiment_analysis": {
    "polarity": 0.92,
    "subjectivity": 0.75,
    "classification": "very_positive",
    "keywords": ["ótima", "qualidade", "perfeita", "prazo", "recomendo"],
    "topics": ["product_quality", "packaging", "delivery_speed", "seller_service"],
    "model_version": "bert-pt-br-v2.1",
    "analyzed_at": new Date("2026-05-10T10:35:00Z")
  },
  "helpful_votes": 24,
  "metadata": {
    "synced_from_postgres_at": new Date("2026-05-10T10:31:00Z")
  }
});

// Review negativa
db.order_reviews.insertOne({
  "_id": "review_002",
  "order_id": "order_abc456",
  "customer": {
    "customer_id": "cust_002",
    "customer_city": "Rio de Janeiro",
    "customer_state": "RJ"
  },
  "review": {
    "score": 2,
    "title": "Produto com defeito",
    "message": "O produto chegou com defeito. Tentei contato com o vendedor mas não obtive resposta. Decepcionante.",
    "created_at": new Date("2026-05-12T15:45:00Z")
  },
  "sentiment_analysis": {
    "polarity": -0.68,
    "subjectivity": 0.82,
    "classification": "negative",
    "keywords": ["defeito", "não", "resposta", "decepcionante"],
    "topics": ["product_defect", "seller_communication", "customer_service"],
    "model_version": "bert-pt-br-v2.1",
    "analyzed_at": new Date("2026-05-12T15:50:00Z")
  },
  "helpful_votes": 8,
  "metadata": {
    "synced_from_postgres_at": new Date("2026-05-12T15:46:00Z")
  }
});

// Review neutral
db.order_reviews.insertOne({
  "_id": "review_003",
  "order_id": "order_def123",
  "customer": {
    "customer_id": "cust_003",
    "customer_city": "Belo Horizonte",
    "customer_state": "MG"
  },
  "review": {
    "score": 3,
    "title": "Produto OK",
    "message": "Produto atende ao esperado, nada excepcional. Entrega no prazo.",
    "created_at": new Date("2026-05-15T12:20:00Z")
  },
  "sentiment_analysis": {
    "polarity": 0.15,
    "subjectivity": 0.45,
    "classification": "neutral",
    "keywords": ["OK", "esperado", "prazo"],
    "topics": ["product_quality", "delivery_time"],
    "model_version": "bert-pt-br-v2.1",
    "analyzed_at": new Date("2026-05-15T12:25:00Z")
  },
  "helpful_votes": 3,
  "metadata": {
    "synced_from_postgres_at": new Date("2026-05-15T12:21:00Z")
  }
});

// ========================================
// 4. QUERIES DE EJEMPLO
// ========================================

// Query 1: Reviews por score
print("\\n=== Query 1: Reviews de 5 estrellas ===");
db.order_reviews.find(
  { "review.score": 5 },
  { review: 1, "sentiment_analysis.classification": 1 }
).sort({ "review.created_at": -1 }).limit(3).pretty();

// Query 2: Búsqueda de texto
print("\\n=== Query 2: Reviews mencionando 'qualidade' ===");
db.order_reviews.find(
  { $text: { $search: "qualidade" } },
  { score: { $meta: "textScore" }, "review.title": 1, "review.score": 1 }
).sort({ score: { $meta: "textScore" } }).limit(3).pretty();

// Query 3: Análisis de sentimiento
print("\\n=== Query 3: Reviews muy positivas ===");
db.order_reviews.find(
  { "sentiment_analysis.classification": "very_positive" },
  { "review.title": 1, "sentiment_analysis.polarity": 1 }
).limit(3).pretty();

// Query 4: Agregación - Distribución de scores
print("\\n=== Query 4: Distribución de scores ===");
db.order_reviews.aggregate([
  {
    $group: {
      _id: "$review.score",
      count: { $sum: 1 },
      avg_polarity: { $avg: "$sentiment_analysis.polarity" }
    }
  },
  { $sort: { _id: -1 } }
]).pretty();

// Query 5: Agregación - Topics más mencionados
print("\\n=== Query 5: Topics más frecuentes ===");
db.order_reviews.aggregate([
  { $unwind: "$sentiment_analysis.topics" },
  {
    $group: {
      _id: "$sentiment_analysis.topics",
      count: { $sum: 1 }
    }
  },
  { $sort: { count: -1 } },
  { $limit: 5 }
]).pretty();

// ========================================
// 5. RESUMEN
// ========================================

print("\\n========================================");
print("COLECCIÓN order_reviews CREADA");
print("========================================");
print("Validación de schema: Habilitada");
print("Índices creados: 6");
print("  - order_id (unique)");
print("  - score + date (compound)");
print("  - text search (title + message)");
print("  - sentiment classification");
print("  - customer_id");
print("  - helpful_votes");
print("\\nDocumentos de ejemplo insertados: 3");
print("  - 1 review positiva (score 5)");
print("  - 1 review negativa (score 2)");
print("  - 1 review neutral (score 3)");
print("========================================");
