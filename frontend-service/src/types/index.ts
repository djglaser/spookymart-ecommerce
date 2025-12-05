// SpookyMart Frontend Types

export interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  image: string;
  inStock: boolean;
  stockQuantity: number;
}

export interface CartItem {
  product: Product;
  quantity: number;
}

export interface Cart {
  items: CartItem[];
  total: number;
}

export interface Customer {
  name: string;
  email: string;
  address: string;
  city: string;
  zipCode: string;
}

export interface Order {
  id: string;
  customerId: string;
  items: CartItem[];
  total: number;
  status: 'pending' | 'processing' | 'shipped' | 'delivered';
  createdAt: string;
  customer: Customer;
}

export interface ApiResponse<T> {
  success: boolean;
  data: T;
  message?: string;
}
