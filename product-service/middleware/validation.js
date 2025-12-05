const Product = require('../models/product');

/**
 * Validation Middleware for SpookyMart Product Service
 * Validates incoming requests before they reach the route handlers
 */

/**
 * Middleware to validate product creation data
 */
const validateProductCreation = (req, res, next) => {
  try {
    const { error, value } = Product.validate(req.body);
    
    if (error) {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        message: error.details[0].message,
        details: error.details
      });
    }
    
    // Attach validated data to request
    req.validatedData = value;
    next();
  } catch (err) {
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Error during validation'
    });
  }
};

/**
 * Middleware to validate product update data
 */
const validateProductUpdate = (req, res, next) => {
  try {
    // For updates, we allow partial data (not all fields required)
    const updateSchema = Product.validate(req.body);
    
    if (updateSchema.error) {
      return res.status(400).json({
        success: false,
        error: 'Validation Error',
        message: updateSchema.error.details[0].message,
        details: updateSchema.error.details
      });
    }
    
    // Remove fields that shouldn't be updated
    const { id, createdAt, ...updateData } = updateSchema.value;
    req.validatedData = updateData;
    next();
  } catch (err) {
    return res.status(500).json({
      success: false,
      error: 'Internal Server Error',
      message: 'Error during validation'
    });
  }
};

/**
 * Middleware to validate product ID parameter
 */
const validateProductId = (req, res, next) => {
  const { id } = req.params;
  
  if (!id || typeof id !== 'string' || id.trim().length === 0) {
    return res.status(400).json({
      success: false,
      error: 'Invalid Product ID',
      message: 'Product ID is required and must be a valid string'
    });
  }
  
  next();
};

/**
 * Middleware to validate query parameters for product filtering
 */
const validateProductQuery = (req, res, next) => {
  const { category, minPrice, maxPrice, inStock, limit, offset } = req.query;
  
  // Validate category if provided
  if (category) {
    const validCategories = ['Costumes', 'Decorations', 'Candy', 'Masks', 'Props', 'Makeup', 'Accessories', 'Lights'];
    if (!validCategories.includes(category)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid Category',
        message: `Category must be one of: ${validCategories.join(', ')}`
      });
    }
  }
  
  // Validate price range if provided
  if (minPrice && (isNaN(minPrice) || parseFloat(minPrice) < 0)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid Price Range',
      message: 'minPrice must be a positive number'
    });
  }
  
  if (maxPrice && (isNaN(maxPrice) || parseFloat(maxPrice) < 0)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid Price Range',
      message: 'maxPrice must be a positive number'
    });
  }
  
  if (minPrice && maxPrice && parseFloat(minPrice) > parseFloat(maxPrice)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid Price Range',
      message: 'minPrice cannot be greater than maxPrice'
    });
  }
  
  // Validate pagination parameters
  if (limit && (isNaN(limit) || parseInt(limit) < 1 || parseInt(limit) > 100)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid Limit',
      message: 'limit must be a number between 1 and 100'
    });
  }
  
  if (offset && (isNaN(offset) || parseInt(offset) < 0)) {
    return res.status(400).json({
      success: false,
      error: 'Invalid Offset',
      message: 'offset must be a non-negative number'
    });
  }
  
  // Validate inStock parameter
  if (inStock && !['true', 'false'].includes(inStock.toLowerCase())) {
    return res.status(400).json({
      success: false,
      error: 'Invalid Stock Filter',
      message: 'inStock must be true or false'
    });
  }
  
  next();
};

/**
 * Generic error handler middleware
 */
const errorHandler = (err, req, res, next) => {
  console.error('Error:', err);
  
  // Handle specific error types
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      success: false,
      error: 'Validation Error',
      message: err.message
    });
  }
  
  if (err.name === 'CastError') {
    return res.status(400).json({
      success: false,
      error: 'Invalid Data Format',
      message: 'Invalid data format provided'
    });
  }
  
  // Default error response
  res.status(500).json({
    success: false,
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'production' 
      ? 'Something went wrong' 
      : err.message
  });
};

module.exports = {
  validateProductCreation,
  validateProductUpdate,
  validateProductId,
  validateProductQuery,
  errorHandler
};
