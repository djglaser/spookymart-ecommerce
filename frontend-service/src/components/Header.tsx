import React from 'react';
import { Link } from 'react-router-dom';

interface HeaderProps {
  cartItemCount: number;
}

const Header: React.FC<HeaderProps> = ({ cartItemCount }) => {
  return (
    <header className="header">
      <div className="header-container">
        <Link to="/" className="logo">
          <h1>🎃 SpookyMart</h1>
        </Link>
        
        <nav className="nav">
          <Link to="/" className="nav-link">
            Products
          </Link>
          <Link to="/cart" className="nav-link cart-link">
            🛒 Cart ({cartItemCount})
          </Link>
        </nav>
      </div>
    </header>
  );
};

export default Header;
