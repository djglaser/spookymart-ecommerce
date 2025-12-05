const Joi = require('joi');
const { v4: uuidv4 } = require('uuid');

/**
 * Product Model for SpookyMart Halloween Store
 * Defines the structure and validation for Halloween products
 */

// Joi validation schema for product data
const productSchema = Joi.object({
  id: Joi.string().optional(), // Auto-generated if not provided
  name: Joi.string().min(3).max(100).required(),
  description: Joi.string().min(10).max(500).required(),
  price: Joi.number().positive().precision(2).required(),
  category: Joi.string().valid(
    'Costumes',
    'Decorations', 
    'Candy',
    'Masks',
    'Props',
    'Makeup',
    'Accessories',
    'Lights'
  ).required(),
  stock: Joi.number().integer().min(0).required(),
  imageUrl: Joi.string().uri().optional(),
  tags: Joi.array().items(Joi.string()).optional(),
  isActive: Joi.boolean().default(true),
  createdAt: Joi.date().optional(),
  updatedAt: Joi.date().optional()
});

class Product {
  constructor(data) {
    // Validate the product data
    const { error, value } = productSchema.validate(data);
    if (error) {
      throw new Error(`Product validation error: ${error.details[0].message}`);
    }

    // Set properties with defaults
    this.id = value.id || uuidv4();
    this.name = value.name;
    this.description = value.description;
    this.price = value.price;
    this.category = value.category;
    this.stock = value.stock;
    this.imageUrl = value.imageUrl || '';
    this.tags = value.tags || [];
    this.isActive = value.isActive !== undefined ? value.isActive : true;
    this.createdAt = value.createdAt || new Date().toISOString();
    this.updatedAt = value.updatedAt || new Date().toISOString();
  }

  /**
   * Convert product to JSON format
   */
  toJSON() {
    return {
      id: this.id,
      name: this.name,
      description: this.description,
      price: this.price,
      category: this.category,
      stock: this.stock,
      imageUrl: this.imageUrl,
      tags: this.tags,
      isActive: this.isActive,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt
    };
  }

  /**
   * Update product properties
   */
  update(data) {
    // Validate update data (excluding id and timestamps)
    const updateSchema = productSchema.fork(['id', 'createdAt'], (schema) => schema.forbidden());
    const { error, value } = updateSchema.validate(data);
    
    if (error) {
      throw new Error(`Product update validation error: ${error.details[0].message}`);
    }

    // Update properties
    Object.keys(value).forEach(key => {
      if (key !== 'id' && key !== 'createdAt') {
        this[key] = value[key];
      }
    });

    this.updatedAt = new Date().toISOString();
    return this;
  }

  /**
   * Check if product is in stock
   */
  isInStock() {
    return this.stock > 0 && this.isActive;
  }

  /**
   * Reduce stock quantity (for order processing)
   */
  reduceStock(quantity) {
    if (quantity > this.stock) {
      throw new Error('Insufficient stock');
    }
    this.stock -= quantity;
    this.updatedAt = new Date().toISOString();
    return this;
  }
}

// Static validation method
Product.validate = (data) => {
  return productSchema.validate(data);
};

module.exports = Product;
