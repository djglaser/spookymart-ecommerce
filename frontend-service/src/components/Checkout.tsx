import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { CartItem, Customer } from '../types';
import { apiService } from '../services';

interface CheckoutProps {
  items: CartItem[];
  total: number;
  onOrderComplete: () => void;
}

const Checkout: React.FC<CheckoutProps> = ({ items, total, onOrderComplete }) => {
  const navigate = useNavigate();
  const [customer, setCustomer] = useState<Customer>({
    name: '',
    email: '',
    address: '',
    city: '',
    zipCode: ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const formatPrice = (price: number) => {
    return `$${price.toFixed(2)}`;
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setCustomer(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const validateForm = () => {
    if (!customer.name.trim()) return 'Name is required';
    if (!customer.email.trim()) return 'Email is required';
    if (!customer.address.trim()) return 'Address is required';
    if (!customer.city.trim()) return 'City is required';
    if (!customer.zipCode.trim()) return 'Zip code is required';
    
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(customer.email)) return 'Please enter a valid email';
    
    return null;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    const validationError = validateForm();
    if (validationError) {
      setError(validationError);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const orderData = {
        customer,
        items: items.map(item => ({
          productId: item.product.id,
          quantity: item.quantity,
          price: item.product.price
        })),
        total
      };

      await apiService.createOrder(orderData);
      onOrderComplete();
      navigate('/');
      alert('🎉 Order placed successfully! Thank you for shopping at SpookyMart!');
    } catch (err) {
      setError('Failed to place order. Please try again.');
      console.error('Order creation error:', err);
    } finally {
      setLoading(false);
    }
  };

  if (items.length === 0) {
    return (
      <div className="checkout">
        <h2>🛒 Checkout</h2>
        <div className="empty-checkout">
          <p>Your cart is empty!</p>
          <Link to="/" className="continue-shopping-btn">
            Continue Shopping
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="checkout">
      <h2>🛒 Checkout</h2>
      
      <div className="checkout-container">
        <div className="order-summary">
          <h3>Order Summary</h3>
          <div className="order-items">
            {items.map((item) => (
              <div key={item.product.id} className="order-item">
                <span className="item-name">{item.product.name}</span>
                <span className="item-quantity">x{item.quantity}</span>
                <span className="item-price">{formatPrice(item.product.price * item.quantity)}</span>
              </div>
            ))}
          </div>
          <div className="order-total">
            <strong>Total: {formatPrice(total)}</strong>
          </div>
        </div>

        <div className="customer-form">
          <h3>Shipping Information</h3>
          {error && <div className="error-message">{error}</div>}
          
          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label htmlFor="name">Full Name *</label>
              <input
                type="text"
                id="name"
                name="name"
                value={customer.name}
                onChange={handleInputChange}
                required
              />
            </div>

            <div className="form-group">
              <label htmlFor="email">Email *</label>
              <input
                type="email"
                id="email"
                name="email"
                value={customer.email}
                onChange={handleInputChange}
                required
              />
            </div>

            <div className="form-group">
              <label htmlFor="address">Address *</label>
              <input
                type="text"
                id="address"
                name="address"
                value={customer.address}
                onChange={handleInputChange}
                required
              />
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="city">City *</label>
                <input
                  type="text"
                  id="city"
                  name="city"
                  value={customer.city}
                  onChange={handleInputChange}
                  required
                />
              </div>

              <div className="form-group">
                <label htmlFor="zipCode">Zip Code *</label>
                <input
                  type="text"
                  id="zipCode"
                  name="zipCode"
                  value={customer.zipCode}
                  onChange={handleInputChange}
                  required
                />
              </div>
            </div>

            <div className="form-actions">
              <Link to="/cart" className="back-to-cart-btn">
                Back to Cart
              </Link>
              <button 
                type="submit" 
                className="place-order-btn"
                disabled={loading}
              >
                {loading ? 'Placing Order...' : `Place Order - ${formatPrice(total)}`}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default Checkout;
