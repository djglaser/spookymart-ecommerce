import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { Product, CartItem } from './types';
import { apiService } from './services';
import ProductList from './components/ProductList';
import Cart from './components/Cart';
import Checkout from './components/Checkout';
import Header from './components/Header';
import './App.css';

function App() {
  const [products, setProducts] = useState<Product[]>([]);
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadProducts();
  }, []);

  const loadProducts = async () => {
    try {
      setLoading(true);
      const productsData = await apiService.getProducts();
      setProducts(productsData);
      setError(null);
    } catch (err) {
      setError('Failed to load products. Please try again later.');
      console.error('Error loading products:', err);
    } finally {
      setLoading(false);
    }
  };

  const addToCart = (product: Product, quantity: number = 1) => {
    setCartItems(prevItems => {
      const existingItem = prevItems.find(item => item.product.id === product.id);
      
      if (existingItem) {
        return prevItems.map(item =>
          item.product.id === product.id
            ? { ...item, quantity: item.quantity + quantity }
            : item
        );
      } else {
        return [...prevItems, { product, quantity }];
      }
    });
  };

  const removeFromCart = (productId: string) => {
    setCartItems(prevItems => prevItems.filter(item => item.product.id !== productId));
  };

  const updateCartQuantity = (productId: string, quantity: number) => {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }

    setCartItems(prevItems =>
      prevItems.map(item =>
        item.product.id === productId
          ? { ...item, quantity }
          : item
      )
    );
  };

  const clearCart = () => {
    setCartItems([]);
  };

  const getTotalPrice = () => {
    return cartItems.reduce((total, item) => total + (item.product.price * item.quantity), 0);
  };

  const getTotalItems = () => {
    return cartItems.reduce((total, item) => total + item.quantity, 0);
  };

  if (loading) {
    return (
      <div className="app">
        <div className="loading">
          <h2>🎃 Loading SpookyMart...</h2>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="app">
        <div className="error">
          <h2>😱 Oops! Something went wrong</h2>
          <p>{error}</p>
          <button onClick={loadProducts} className="retry-button">
            Try Again
          </button>
        </div>
      </div>
    );
  }

  return (
    <Router>
      <div className="app">
        <Header cartItemCount={getTotalItems()} />
        
        <main className="main-content">
          <Routes>
            <Route 
              path="/" 
              element={
                <ProductList 
                  products={products} 
                  onAddToCart={addToCart}
                />
              } 
            />
            <Route 
              path="/cart" 
              element={
                <Cart 
                  items={cartItems}
                  onUpdateQuantity={updateCartQuantity}
                  onRemoveItem={removeFromCart}
                  total={getTotalPrice()}
                />
              } 
            />
            <Route 
              path="/checkout" 
              element={
                <Checkout 
                  items={cartItems}
                  total={getTotalPrice()}
                  onOrderComplete={clearCart}
                />
              } 
            />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;
