import React from 'react';
import { Link } from 'react-router-dom';
import { CartItem } from '../types';

interface CartProps {
  items: CartItem[];
  onUpdateQuantity: (productId: string, quantity: number) => void;
  onRemoveItem: (productId: string) => void;
  total: number;
}

const Cart: React.FC<CartProps> = ({ items, onUpdateQuantity, onRemoveItem, total }) => {
  const formatPrice = (price: number) => {
    return `$${price.toFixed(2)}`;
  };

  if (items.length === 0) {
    return (
      <div className="cart">
        <h2>🛒 Your Cart</h2>
        <div className="empty-cart">
          <p>Your cart is empty!</p>
          <Link to="/" className="continue-shopping-btn">
            Continue Shopping
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="cart">
      <h2>🛒 Your Cart ({items.length} items)</h2>
      
      <div className="cart-items">
        {items.map((item) => (
          <div key={item.product.id} className="cart-item">
            <div className="cart-item-image">
              <img 
                src={item.product.image || '/placeholder-product.jpg'} 
                alt={item.product.name}
                onError={(e) => {
                  const target = e.target as HTMLImageElement;
                  target.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWxsPSIjZGRkIi8+PHRleHQgeD0iNTAlIiB5PSI1MCUiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxMiIgZmlsbD0iIzk5OSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPk5vIEltYWdlPC90ZXh0Pjwvc3ZnPg==';
                }}
              />
            </div>
            
            <div className="cart-item-details">
              <h3 className="cart-item-name">{item.product.name}</h3>
              <p className="cart-item-price">{formatPrice(item.product.price)} each</p>
              <p className="cart-item-category">Category: {item.product.category}</p>
            </div>
            
            <div className="cart-item-quantity">
              <label htmlFor={`quantity-${item.product.id}`}>Quantity:</label>
              <div className="quantity-controls">
                <button 
                  onClick={() => onUpdateQuantity(item.product.id, item.quantity - 1)}
                  disabled={item.quantity <= 1}
                  className="quantity-btn"
                >
                  -
                </button>
                <input
                  id={`quantity-${item.product.id}`}
                  type="number"
                  min="1"
                  max={item.product.stockQuantity}
                  value={item.quantity}
                  onChange={(e) => onUpdateQuantity(item.product.id, parseInt(e.target.value) || 1)}
                  className="quantity-input"
                />
                <button 
                  onClick={() => onUpdateQuantity(item.product.id, item.quantity + 1)}
                  disabled={item.quantity >= item.product.stockQuantity}
                  className="quantity-btn"
                >
                  +
                </button>
              </div>
            </div>
            
            <div className="cart-item-total">
              <p className="item-total">{formatPrice(item.product.price * item.quantity)}</p>
              <button 
                onClick={() => onRemoveItem(item.product.id)}
                className="remove-btn"
              >
                🗑️ Remove
              </button>
            </div>
          </div>
        ))}
      </div>
      
      <div className="cart-summary">
        <div className="cart-total">
          <h3>Total: {formatPrice(total)}</h3>
        </div>
        
        <div className="cart-actions">
          <Link to="/" className="continue-shopping-btn">
            Continue Shopping
          </Link>
          <Link to="/checkout" className="checkout-btn">
            Proceed to Checkout
          </Link>
        </div>
      </div>
    </div>
  );
};

export default Cart;
