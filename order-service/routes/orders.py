"""
Order Routes for SpookyMart Order Processing Service
Simplified for demo - no file storage, stdout printing only
"""

import json
from datetime import datetime
from typing import Dict, Any
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Body
from fastapi.responses import JSONResponse

from models.order import Order, OrderCreate, OrderResponse, OrderListResponse

router = APIRouter()

# In-memory storage for demo (will be lost on restart)
orders_storage = {}

# Dummy data for demo
DUMMY_ORDERS = [
    {
        "id": "order-001",
        "customer_email": "john.doe@spookymart.com",
        "customer_name": "John Doe",
        "customer_phone": "555-0123",
        "items": [
            {
                "product_id": "prod-001",
                "product_name": "Vampire Costume Deluxe",
                "quantity": 1,
                "unit_price": 49.99
            }
        ],
        "shipping_address": {
            "street": "123 Halloween St",
            "city": "Spookyville",
            "state": "CA",
            "zip_code": "90210",
            "country": "USA"
        },
        "status": "confirmed",
        "total_amount": 49.99,
        "created_at": "2025-11-01T20:00:00Z"
    },
    {
        "id": "order-002",
        "customer_email": "jane.smith@spookymart.com",
        "customer_name": "Jane Smith",
        "customer_phone": "555-0456",
        "items": [
            {
                "product_id": "prod-002",
                "product_name": "Spooky Jack-o'-Lantern",
                "quantity": 2,
                "unit_price": 24.99
            },
            {
                "product_id": "prod-003",
                "product_name": "Witch Hat Classic",
                "quantity": 1,
                "unit_price": 15.99
            }
        ],
        "shipping_address": {
            "street": "456 Pumpkin Ave",
            "city": "Ghosttown",
            "state": "NY",
            "zip_code": "10001",
            "country": "USA"
        },
        "status": "shipped",
        "total_amount": 65.97,
        "created_at": "2025-11-01T19:30:00Z"
    },
    {
        "id": "order-003",
        "customer_email": "bob.wilson@spookymart.com",
        "customer_name": "Bob Wilson",
        "customer_phone": "555-0789",
        "items": [
            {
                "product_id": "prod-004",
                "product_name": "Halloween Candy Mix",
                "quantity": 3,
                "unit_price": 12.99
            }
        ],
        "shipping_address": {
            "street": "789 Candy Lane",
            "city": "Sweetville",
            "state": "TX",
            "zip_code": "75001",
            "country": "USA"
        },
        "status": "delivered",
        "total_amount": 38.97,
        "created_at": "2025-11-01T18:15:00Z"
    }
]


@router.get("/", response_model=OrderListResponse)
async def get_orders():
    """Get all orders - returns dummy data for demo"""
    try:
        print("=" * 80)
        print("🚨 [DEBUG] GET ORDERS REQUEST RECEIVED! 🚨")
        print("🚨 [DEBUG] FastAPI Order Service is ALIVE and processing GET /api/orders")
        print("🚨 [DEBUG] Request reached Order Service successfully!")
        print("=" * 80)
        print("🎃 GET ORDERS REQUEST - Returning dummy data for demo")
        print(f"📦 Total dummy orders: {len(DUMMY_ORDERS)}")
        
        return OrderListResponse(
            success=True,
            orders=DUMMY_ORDERS,
            total=len(DUMMY_ORDERS)
        )
    except Exception as e:
        print(f"❌ Error getting orders: {str(e)}")
        raise HTTPException(status_code=500, detail={
            "error": "Internal Server Error",
            "message": "Failed to retrieve orders"
        })


@router.get("/{order_id}")
async def get_order(order_id: str):
    """Get a specific order by ID"""
    try:
        print(f"🎃 GET ORDER REQUEST - ID: {order_id}")
        
        # Check in-memory storage first
        if order_id in orders_storage:
            order = orders_storage[order_id]
            print(f"📦 Found order in memory: {order_id}")
            return OrderResponse(
                success=True,
                message="Order retrieved successfully",
                order=order
            )
        
        # Check dummy data
        for order in DUMMY_ORDERS:
            if order["id"] == order_id:
                print(f"📦 Found order in dummy data: {order_id}")
                return OrderResponse(
                    success=True,
                    message="Order retrieved successfully",
                    order=order
                )
        
        print(f"❌ Order not found: {order_id}")
        raise HTTPException(status_code=404, detail={
            "error": "Not Found",
            "message": f"Order {order_id} not found"
        })
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error getting order {order_id}: {str(e)}")
        raise HTTPException(status_code=500, detail={
            "error": "Internal Server Error",
            "message": f"Failed to retrieve order {order_id}"
        })


@router.post("/", response_model=OrderResponse)
async def create_order(order_data: Dict[str, Any] = Body(...)):
    """Create a new order - prints to stdout, stores in memory"""
    try:
        print("=" * 100)
        print("🚨🚨🚨 [CRITICAL DEBUG] POST ORDER REQUEST RECEIVED! 🚨🚨🚨")
        print("=" * 100)
        print("🚨 [DEBUG] FastAPI Order Service is ALIVE and processing POST /api/orders")
        print("🚨 [DEBUG] POST request successfully reached Order Service!")
        print(f"🚨 [DEBUG] Raw request data type: {type(order_data)}")
        print(f"🚨 [DEBUG] Raw request data: {json.dumps(order_data, indent=2)}")
        print("🚨 [DEBUG] This proves API Gateway routing is working!")
        print("=" * 100)
        
        # Generate order ID
        order_id = str(uuid4())
        print(f"🚨 [DEBUG] Generated Order ID: {order_id}")
        
        # Create order with minimal validation
        print("🚨 [DEBUG] Processing order data...")
        order = {
            "id": order_id,
            "customer_email": order_data.get("customer_email", ""),
            "customer_name": order_data.get("customer_name", ""),
            "customer_phone": order_data.get("customer_phone", ""),
            "items": order_data.get("items", []),
            "shipping_address": order_data.get("shipping_address", {}),
            "status": "pending",
            "total_amount": 0.0,
            "created_at": datetime.utcnow().isoformat()
        }
        print(f"🚨 [DEBUG] Order object created: {json.dumps(order, indent=2)}")
        
        # Calculate total
        print("🚨 [DEBUG] Calculating order total...")
        total = 0.0
        for i, item in enumerate(order["items"]):
            quantity = item.get("quantity", 1)
            unit_price = item.get("unit_price", 0.0)
            item_total = quantity * unit_price
            print(f"🚨 [DEBUG] Item {i+1}: {quantity} x ${unit_price} = ${item_total}")
            total += item_total
        order["total_amount"] = total
        print(f"🚨 [DEBUG] Final total calculated: ${total}")
        
        # Store in memory
        print("🚨 [DEBUG] Storing order in memory...")
        orders_storage[order_id] = order
        print(f"🚨 [DEBUG] Order stored! Memory now contains {len(orders_storage)} orders")
        
        # Print to stdout for demo
        print("🎃" * 50)
        print("🎃 NEW SPOOKYMART ORDER CREATED! 🎃")
        print("🎃" * 50)
        print(f"📧 Customer: {order['customer_name']} ({order['customer_email']})")
        print(f"📞 Phone: {order['customer_phone']}")
        print(f"🆔 Order ID: {order_id}")
        print(f"💰 Total: ${order['total_amount']:.2f}")
        print("📦 Items:")
        for i, item in enumerate(order["items"], 1):
            print(f"   {i}. {item.get('product_name', 'Unknown')} x{item.get('quantity', 1)} @ ${item.get('unit_price', 0):.2f}")
        print(f"🏠 Shipping to: {order['shipping_address'].get('street', '')}, {order['shipping_address'].get('city', '')}")
        print(f"⏰ Created: {order['created_at']}")
        print("🎃" * 50)
        
        print("🚨 [DEBUG] Creating OrderResponse...")
        response = OrderResponse(
            success=True,
            message="Order created successfully",
            order=order
        )
        print("🚨 [DEBUG] OrderResponse created successfully!")
        print("🚨 [DEBUG] About to return successful response to API Gateway")
        print("=" * 100)
        
        return response
        
    except Exception as e:
        print("=" * 100)
        print("🚨🚨🚨 [CRITICAL ERROR] POST ORDER FAILED! 🚨🚨🚨")
        print("=" * 100)
        print(f"🚨 [ERROR] Exception type: {type(e).__name__}")
        print(f"� [ERROR] Exception message: {str(e)}")
        print(f"🚨 [ERROR] Exception args: {e.args}")
        
        import traceback
        print("🚨 [ERROR] Full traceback:")
        print(traceback.format_exc())
        print("=" * 100)
        
        raise HTTPException(status_code=500, detail={
            "error": "Internal Server Error",
            "message": "Failed to create order",
            "debug_info": f"Exception: {str(e)}"
        })


@router.put("/{order_id}")
async def update_order(order_id: str, update_data: Dict[str, Any]):
    """Update an order"""
    try:
        print(f"🎃 UPDATE ORDER REQUEST - ID: {order_id}")
        
        if order_id not in orders_storage:
            raise HTTPException(status_code=404, detail={
                "error": "Not Found",
                "message": f"Order {order_id} not found"
            })
        
        # Update order
        order = orders_storage[order_id]
        for key, value in update_data.items():
            if key in order:
                order[key] = value
        
        print(f"✅ Order {order_id} updated successfully")
        print(f"📝 Updated fields: {list(update_data.keys())}")
        
        return OrderResponse(
            success=True,
            message="Order updated successfully",
            order=order
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error updating order {order_id}: {str(e)}")
        raise HTTPException(status_code=500, detail={
            "error": "Internal Server Error",
            "message": f"Failed to update order {order_id}"
        })


@router.delete("/{order_id}")
async def cancel_order(order_id: str):
    """Cancel/delete an order"""
    try:
        print(f"🎃 CANCEL ORDER REQUEST - ID: {order_id}")
        
        if order_id in orders_storage:
            del orders_storage[order_id]
            print(f"✅ Order {order_id} cancelled successfully")
            
            return {
                "success": True,
                "message": f"Order {order_id} cancelled successfully"
            }
        else:
            raise HTTPException(status_code=404, detail={
                "error": "Not Found",
                "message": f"Order {order_id} not found"
            })
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error cancelling order {order_id}: {str(e)}")
        raise HTTPException(status_code=500, detail={
            "error": "Internal Server Error",
            "message": f"Failed to cancel order {order_id}"
        })


@router.get("/{order_id}/status")
async def get_order_status(order_id: str):
    """Get order status"""
    try:
        print(f"🎃 GET ORDER STATUS - ID: {order_id}")
        
        # Check in-memory storage
        if order_id in orders_storage:
            order = orders_storage[order_id]
            return {
                "success": True,
                "order_id": order_id,
                "status": order["status"],
                "created_at": order["created_at"]
            }
        
        # Check dummy data
        for order in DUMMY_ORDERS:
            if order["id"] == order_id:
                return {
                    "success": True,
                    "order_id": order_id,
                    "status": order["status"],
                    "created_at": order["created_at"]
                }
        
        raise HTTPException(status_code=404, detail={
            "error": "Not Found",
            "message": f"Order {order_id} not found"
        })
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error getting order status {order_id}: {str(e)}")
        raise HTTPException(status_code=500, detail={
            "error": "Internal Server Error",
            "message": f"Failed to get order status for {order_id}"
        })
