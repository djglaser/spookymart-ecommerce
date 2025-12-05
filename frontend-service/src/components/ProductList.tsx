import React from 'react';
import { Product } from '../types';

interface ProductListProps {
  products: Product[];
  onAddToCart: (product: Product, quantity?: number) => void;
}

const ProductList: React.FC<ProductListProps> = ({ products, onAddToCart }) => {
  const formatPrice = (price: number) => {
    return `$${price.toFixed(2)}`;
  };

  return (
    <div className="product-list">
      <h2>🎃 Halloween Products</h2>
      
      {products.length === 0 ? (
        <div className="no-products">
          <p>No products available at the moment.</p>
        </div>
      ) : (
        <div className="products-grid">
          {products.map((product) => (
            <div key={product.id} className="product-card">
              <div className="product-image">
                <img 
                  src={product.image || '/placeholder-product.jpg'} 
                  alt={product.name}
                  onError={(e) => {
                    const target = e.target as HTMLImageElement;
                    target.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzk5OSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==';
                  }}
                />
              </div>
              
              <div className="product-info">
                <h3 className="product-name">{product.name}</h3>
                <p className="product-description">{product.description}</p>
                <div className="product-details">
                  <span className="product-category">Category: {product.category}</span>
                  <span className="product-price">{formatPrice(product.price)}</span>
                </div>
                
                <div className="product-stock">
                  {product.inStock ? (
                    <span className="in-stock">✅ In Stock ({product.stockQuantity} available)</span>
                  ) : (
                    <span className="out-of-stock">❌ Out of Stock</span>
                  )}
                </div>
                
                <button 
                  className="add-to-cart-btn"
                  onClick={() => onAddToCart(product)}
                  disabled={!product.inStock}
                >
                  {product.inStock ? '🛒 Add to Cart' : 'Out of Stock'}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default ProductList;
