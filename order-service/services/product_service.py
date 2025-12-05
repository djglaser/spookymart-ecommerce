"""
Product Service Integration for SpookyMart Order Processing Service
Handles communication with the Product Service
"""

import asyncio
from typing import Dict, List, Optional
import httpx
import structlog
from datetime import datetime

logger = structlog.get_logger()


class ProductServiceError(Exception):
    """Custom exception for Product Service errors"""
    pass


class ProductService:
    """Service class for interacting with the Product Service"""
    
    def __init__(self, base_url: str = "http://localhost:3001"):
        self.base_url = base_url.rstrip('/')
        self.timeout = 5.0
        
    async def get_product(self, product_id: str) -> Optional[Dict]:
        """
        Get a single product by ID from Product Service
        
        Args:
            product_id: The product ID to fetch
            
        Returns:
            Product data dictionary or None if not found
            
        Raises:
            ProductServiceError: If there's an error communicating with the service
        """
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(f"{self.base_url}/api/products/{product_id}")
                
                if response.status_code == 404:
                    logger.warning("Product not found", product_id=product_id)
                    return None
                
                if response.status_code != 200:
                    logger.error(
                        "Product service error",
                        product_id=product_id,
                        status_code=response.status_code,
                        response=response.text
                    )
                    raise ProductServiceError(f"Product service returned {response.status_code}")
                
                data = response.json()
                if not data.get('success'):
                    logger.error("Product service returned unsuccessful response", data=data)
                    raise ProductServiceError("Product service returned unsuccessful response")
                
                return data.get('data', {}).get('product')
                
        except httpx.TimeoutException:
            logger.error("Product service timeout", product_id=product_id)
            raise ProductServiceError("Product service timeout")
        except httpx.RequestError as e:
            logger.error("Product service request error", product_id=product_id, error=str(e))
            raise ProductServiceError(f"Product service request error: {str(e)}")
    
    async def get_products_batch(self, product_ids: List[str]) -> Dict[str, Dict]:
        """
        Get multiple products by their IDs
        
        Args:
            product_ids: List of product IDs to fetch
            
        Returns:
            Dictionary mapping product_id to product data
            
        Raises:
            ProductServiceError: If there's an error communicating with the service
        """
        if not product_ids:
            return {}
        
        # Create tasks for concurrent requests
        tasks = [self.get_product(product_id) for product_id in product_ids]
        
        try:
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            products = {}
            for product_id, result in zip(product_ids, results):
                if isinstance(result, Exception):
                    logger.error("Error fetching product", product_id=product_id, error=str(result))
                    raise ProductServiceError(f"Error fetching product {product_id}: {str(result)}")
                elif result is not None:
                    products[product_id] = result
                    
            return products
            
        except Exception as e:
            logger.error("Batch product fetch error", product_ids=product_ids, error=str(e))
            raise ProductServiceError(f"Batch product fetch error: {str(e)}")
    
    async def check_product_availability(self, product_id: str, quantity: int) -> Dict:
        """
        Check if a product is available in the requested quantity
        
        Args:
            product_id: The product ID to check
            quantity: The quantity needed
            
        Returns:
            Dictionary with availability info:
            {
                "available": bool,
                "stock": int,
                "product": dict or None
            }
        """
        product = await self.get_product(product_id)
        
        if not product:
            return {
                "available": False,
                "stock": 0,
                "product": None,
                "reason": "Product not found"
            }
        
        if not product.get('isActive', False):
            return {
                "available": False,
                "stock": product.get('stock', 0),
                "product": product,
                "reason": "Product is not active"
            }
        
        current_stock = product.get('stock', 0)
        available = current_stock >= quantity
        
        return {
            "available": available,
            "stock": current_stock,
            "product": product,
            "reason": None if available else f"Insufficient stock (need {quantity}, have {current_stock})"
        }
    
    async def validate_order_items(self, order_items: List[Dict]) -> Dict:
        """
        Validate all items in an order for availability and pricing
        
        Args:
            order_items: List of order items with product_id, quantity, unit_price
            
        Returns:
            Dictionary with validation results:
            {
                "valid": bool,
                "items": dict,  # product_id -> validation result
                "errors": list
            }
        """
        validation_result = {
            "valid": True,
            "items": {},
            "errors": []
        }
        
        # Get all product IDs
        product_ids = [item.get('product_id') for item in order_items]
        
        try:
            # Fetch all products in batch
            products = await self.get_products_batch(product_ids)
            
            for item in order_items:
                product_id = item.get('product_id')
                quantity = item.get('quantity', 0)
                expected_price = item.get('unit_price', 0)
                
                # Check if product exists
                if product_id not in products:
                    validation_result["valid"] = False
                    validation_result["errors"].append(f"Product {product_id} not found")
                    validation_result["items"][product_id] = {
                        "valid": False,
                        "reason": "Product not found"
                    }
                    continue
                
                product = products[product_id]
                
                # Check availability
                availability = await self.check_product_availability(product_id, quantity)
                
                if not availability["available"]:
                    validation_result["valid"] = False
                    validation_result["errors"].append(
                        f"Product {product_id}: {availability['reason']}"
                    )
                    validation_result["items"][product_id] = {
                        "valid": False,
                        "reason": availability["reason"],
                        "product": product
                    }
                    continue
                
                # Check price consistency (allow small differences for floating point)
                actual_price = product.get('price', 0)
                if abs(expected_price - actual_price) > 0.01:
                    validation_result["valid"] = False
                    validation_result["errors"].append(
                        f"Product {product_id}: Price mismatch (expected {expected_price}, actual {actual_price})"
                    )
                    validation_result["items"][product_id] = {
                        "valid": False,
                        "reason": f"Price mismatch (expected {expected_price}, actual {actual_price})",
                        "product": product
                    }
                    continue
                
                # Item is valid
                validation_result["items"][product_id] = {
                    "valid": True,
                    "product": product,
                    "available_stock": availability["stock"]
                }
            
            return validation_result
            
        except ProductServiceError as e:
            validation_result["valid"] = False
            validation_result["errors"].append(f"Product service error: {str(e)}")
            return validation_result
    
    async def reserve_products(self, order_items: List[Dict]) -> Dict:
        """
        Reserve products for an order (placeholder for future implementation)
        
        In a real system, this would:
        1. Lock inventory
        2. Create reservations
        3. Set expiration times
        
        Args:
            order_items: List of order items to reserve
            
        Returns:
            Dictionary with reservation results
        """
        # For now, just validate the items
        # In a real implementation, this would actually reserve inventory
        validation_result = await self.validate_order_items(order_items)
        
        if validation_result["valid"]:
            logger.info("Products reserved successfully", 
                       product_ids=[item.get('product_id') for item in order_items])
            return {
                "success": True,
                "reservation_id": f"res_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}",
                "expires_at": datetime.utcnow().isoformat(),
                "items": validation_result["items"]
            }
        else:
            logger.warning("Product reservation failed", errors=validation_result["errors"])
            return {
                "success": False,
                "errors": validation_result["errors"],
                "items": validation_result["items"]
            }
    
    async def health_check(self) -> bool:
        """
        Check if the Product Service is healthy
        
        Returns:
            True if service is healthy, False otherwise
        """
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(f"{self.base_url}/health")
                return response.status_code == 200
        except Exception as e:
            logger.error("Product service health check failed", error=str(e))
            return False


# Global instance
product_service = ProductService()
