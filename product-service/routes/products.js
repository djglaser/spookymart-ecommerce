const express = require('express');
const fs = require('fs').promises;
const path = require('path');
const Product = require('../models/product');
// Validation middleware removed for demo simplicity

const router = express.Router();

// Path to our products data file
const PRODUCTS_FILE = path.join(__dirname, '../data/products.json');

/**
 * Helper function to read products from file
 */
async function readProducts() {
  try {
    const data = await fs.readFile(PRODUCTS_FILE, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error('Error reading products file:', error);
    return [];
  }
}

/**
 * Helper function to write products to file
 */
async function writeProducts(products) {
  try {
    await fs.writeFile(PRODUCTS_FILE, JSON.stringify(products, null, 2));
    return true;
  } catch (error) {
    console.error('Error writing products file:', error);
    return false;
  }
}

/**
 * GET /products
 * Retrieve all products with optional filtering
 * Query parameters:
 * - category: Filter by product category
 * - minPrice, maxPrice: Filter by price range
 * - inStock: Filter by stock availability (true/false)
 * - limit: Number of products to return (default: 50, max: 100)
 * - offset: Number of products to skip (default: 0)
 */
router.get('/', async (req, res) => {
  try {
    const products = await readProducts();
    let filteredProducts = products;

    // Apply filters
    const { category, minPrice, maxPrice, inStock, limit = 50, offset = 0 } = req.query;

    if (category) {
      filteredProducts = filteredProducts.filter(p => p.category === category);
    }

    if (minPrice) {
      filteredProducts = filteredProducts.filter(p => p.price >= parseFloat(minPrice));
    }

    if (maxPrice) {
      filteredProducts = filteredProducts.filter(p => p.price <= parseFloat(maxPrice));
    }

    if (inStock !== undefined) {
      const stockFilter = inStock.toLowerCase() === 'true';
      filteredProducts = filteredProducts.filter(p => 
        stockFilter ? (p.stock > 0 && p.isActive) : (p.stock === 0 || !p.isActive)
      );
    }

    // Apply pagination
    const startIndex = parseInt(offset);
    const endIndex = startIndex + parseInt(limit);
    const paginatedProducts = filteredProducts.slice(startIndex, endIndex);

    res.json({
      success: true,
      data: {
        products: paginatedProducts,
        pagination: {
          total: filteredProducts.length,
          limit: parseInt(limit),
          offset: parseInt(offset),
          hasMore: endIndex < filteredProducts.length
        }
      }
    });
  } catch (error) {
    console.error('Error fetching products:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to fetch products'
    });
  }
});

/**
 * GET /products/:id
 * Retrieve a specific product by ID
 */
router.get('/:id', async (req, res) => {
  try {
    const products = await readProducts();
    const product = products.find(p => p.id === req.params.id);

    if (!product) {
      return res.status(404).json({
        success: false,
        error: 'Product Not Found',
        message: `Product with ID ${req.params.id} not found`
      });
    }

    res.json({
      success: true,
      data: { product }
    });
  } catch (error) {
    console.error('Error fetching product:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to fetch product'
    });
  }
});

/**
 * POST /products
 * Create a new product
 */
router.post('/', async (req, res) => {
  try {
    const products = await readProducts();
    
    // Create new product instance (skip validation for demo)
    const newProduct = new Product(req.body);
    
    // Check if product with same name already exists
    const existingProduct = products.find(p => 
      p.name.toLowerCase() === newProduct.name.toLowerCase()
    );
    
    if (existingProduct) {
      return res.status(409).json({
        success: false,
        error: 'Product Already Exists',
        message: 'A product with this name already exists'
      });
    }

    // Add to products array
    products.push(newProduct.toJSON());
    
    // Save to file
    const saved = await writeProducts(products);
    if (!saved) {
      return res.status(500).json({
        success: false,
        error: 'Save Error',
        message: 'Failed to save product'
      });
    }

    res.status(201).json({
      success: true,
      data: { product: newProduct.toJSON() },
      message: 'Product created successfully'
    });
  } catch (error) {
    console.error('Error creating product:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to create product'
    });
  }
});

/**
 * PUT /products/:id
 * Update an existing product
 */
router.put('/:id', async (req, res) => {
  try {
    const products = await readProducts();
    const productIndex = products.findIndex(p => p.id === req.params.id);

    if (productIndex === -1) {
      return res.status(404).json({
        success: false,
        error: 'Product Not Found',
        message: `Product with ID ${req.params.id} not found`
      });
    }

    // Create product instance and update it (skip validation for demo)
    const existingProduct = new Product(products[productIndex]);
    const updatedProduct = existingProduct.update(req.body);

    // Update in array
    products[productIndex] = updatedProduct.toJSON();
    
    // Save to file
    const saved = await writeProducts(products);
    if (!saved) {
      return res.status(500).json({
        success: false,
        error: 'Save Error',
        message: 'Failed to update product'
      });
    }

    res.json({
      success: true,
      data: { product: updatedProduct.toJSON() },
      message: 'Product updated successfully'
    });
  } catch (error) {
    console.error('Error updating product:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to update product'
    });
  }
});

/**
 * DELETE /products/:id
 * Delete a product (soft delete by setting isActive to false)
 */
router.delete('/:id', async (req, res) => {
  try {
    const products = await readProducts();
    const productIndex = products.findIndex(p => p.id === req.params.id);

    if (productIndex === -1) {
      return res.status(404).json({
        success: false,
        error: 'Product Not Found',
        message: `Product with ID ${req.params.id} not found`
      });
    }

    // Soft delete - set isActive to false
    products[productIndex].isActive = false;
    products[productIndex].updatedAt = new Date().toISOString();
    
    // Save to file
    const saved = await writeProducts(products);
    if (!saved) {
      return res.status(500).json({
        success: false,
        error: 'Save Error',
        message: 'Failed to delete product'
      });
    }

    res.json({
      success: true,
      message: 'Product deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting product:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to delete product'
    });
  }
});

/**
 * GET /products/categories/list
 * Get list of all available product categories
 */
router.get('/categories/list', async (req, res) => {
  try {
    const categories = ['Costumes', 'Decorations', 'Candy', 'Masks', 'Props', 'Makeup', 'Accessories', 'Lights'];
    
    res.json({
      success: true,
      data: { categories }
    });
  } catch (error) {
    console.error('Error fetching categories:', error);
    res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Failed to fetch categories'
    });
  }
});

module.exports = router;
