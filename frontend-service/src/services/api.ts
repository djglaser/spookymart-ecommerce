// SpookyMart API Service

import { Product, Order, Customer, ApiResponse } from '../types';

// Use environment variable for API URL, fallback to ALB URL
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://spookymart-alb-1978027172.us-west-2.elb.amazonaws.com';

class ApiService {
  private async fetchApi<T>(endpoint: string, options?: RequestInit): Promise<ApiResponse<T>> {
    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        headers: {
          'Content-Type': 'application/json',
          ...options?.headers,
        },
        ...options,
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error('API Error:', error);
      throw error;
    }
  }

  // Product API methods
  async getProducts(): Promise<Product[]> {
    const response = await this.fetchApi<{ products: Product[] }>('/api/products');
    return response.data.products;
  }

  async getProduct(id: string): Promise<Product> {
    const response = await this.fetchApi<Product>(`/api/products/${id}`);
    return response.data;
  }

  // Order API methods
  async createOrder(orderData: {
    customer: Customer;
    items: Array<{ productId: string; quantity: number; price: number }>;
    total: number;
  }): Promise<Order> {
    const response = await this.fetchApi<Order>('/api/orders', {
      method: 'POST',
      body: JSON.stringify(orderData),
    });
    return response.data;
  }

  async getOrders(): Promise<Order[]> {
    const response = await this.fetchApi<{ orders: Order[] }>('/api/orders');
    return response.data.orders;
  }

  async getOrder(id: string): Promise<Order> {
    const response = await this.fetchApi<Order>(`/api/orders/${id}`);
    return response.data;
  }

  // Health check
  async healthCheck(): Promise<any> {
    const response = await this.fetchApi<any>('/health');
    return response.data;
  }
}

export const apiService = new ApiService();
