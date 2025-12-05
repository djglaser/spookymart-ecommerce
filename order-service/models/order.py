"""
Simplified Order Models for SpookyMart Order Processing Service
No validation, minimal structure for demo purposes
"""

from datetime import datetime
from typing import List, Optional, Dict, Any
from uuid import uuid4
from pydantic import BaseModel


class OrderItem(BaseModel):
    """Individual item in an order - no validation"""
    product_id: str = ""
    product_name: str = ""
    quantity: int = 1
    unit_price: float = 0.0


class ShippingAddress(BaseModel):
    """Shipping address - no validation"""
    street: str = ""
    city: str = ""
    state: str = ""
    zip_code: str = ""
    country: str = "US"


class Order(BaseModel):
    """Simplified Order model - no validation"""
    id: str = ""
    customer_email: str = ""
    customer_name: str = ""
    customer_phone: str = ""
    items: List[OrderItem] = []
    shipping_address: ShippingAddress = ShippingAddress()
    status: str = "pending"
    total_amount: float = 0.0
    created_at: str = ""
    
    def __init__(self, **data):
        # Set defaults
        if not data.get('id'):
            data['id'] = str(uuid4())
        if not data.get('created_at'):
            data['created_at'] = datetime.utcnow().isoformat()
        if not data.get('status'):
            data['status'] = 'pending'
        
        # Calculate total if items provided
        if data.get('items'):
            total = 0.0
            for item in data['items']:
                if isinstance(item, dict):
                    total += item.get('quantity', 1) * item.get('unit_price', 0.0)
                else:
                    total += item.quantity * item.unit_price
            data['total_amount'] = total
        
        super().__init__(**data)


class OrderCreate(BaseModel):
    """Simple order creation model - no validation"""
    customer_email: str = ""
    customer_name: str = ""
    customer_phone: str = ""
    items: List[Dict[str, Any]] = []
    shipping_address: Dict[str, Any] = {}


class OrderResponse(BaseModel):
    """Simple response model"""
    success: bool = True
    message: str = ""
    order: Optional[Dict[str, Any]] = None


class OrderListResponse(BaseModel):
    """Simple list response model"""
    success: bool = True
    orders: List[Dict[str, Any]] = []
    total: int = 0
