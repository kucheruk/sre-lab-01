#!/usr/bin/env python3
import asyncio
import aiohttp
import random
import time
import json
from datetime import datetime
import argparse

class LoadGenerator:
    def __init__(self, base_url, target_rps):
        self.base_url = base_url
        self.target_rps = target_rps
        self.customers = [f"CUST{i:03d}" for i in range(1, 6)]
        self.products = [f"PROD{i:03d}" for i in range(1, 21)]
        self.stats = {
            'total_requests': 0,
            'successful_requests': 0,
            'failed_requests': 0,
            'status_codes': {},
            'latencies': []
        }
        
    async def make_request(self, session, method, url, json_data=None):
        start_time = time.time()
        try:
            async with session.request(method, url, json=json_data) as response:
                latency = (time.time() - start_time) * 1000  # Convert to ms
                status = response.status
                
                self.stats['total_requests'] += 1
                self.stats['latencies'].append(latency)
                self.stats['status_codes'][status] = self.stats['status_codes'].get(status, 0) + 1
                
                if 200 <= status < 300:
                    self.stats['successful_requests'] += 1
                else:
                    self.stats['failed_requests'] += 1
                    
                return await response.json() if response.content_type == 'application/json' else None
                
        except Exception as e:
            self.stats['total_requests'] += 1
            self.stats['failed_requests'] += 1
            print(f"Request failed: {e}")
            return None
            
    async def get_all_orders(self, session):
        return await self.make_request(session, 'GET', f"{self.base_url}/api/orders")
        
    async def get_order(self, session):
        order_id = random.randint(1, 20)
        return await self.make_request(session, 'GET', f"{self.base_url}/api/orders/{order_id}")
        
    async def create_order(self, session):
        items = []
        for _ in range(random.randint(1, 3)):
            items.append({
                'productId': random.choice(self.products),
                'quantity': random.randint(1, 5),
                'price': random.randint(10, 100)
            })
            
        payload = {
            'customerId': random.choice(self.customers),
            'items': items
        }
        return await self.make_request(session, 'POST', f"{self.base_url}/api/orders", payload)
        
    async def update_order(self, session):
        order_id = random.randint(1, 20)
        payload = {
            'status': random.choice(['Pending', 'Processing', 'Shipped', 'Delivered'])
        }
        return await self.make_request(session, 'PUT', f"{self.base_url}/api/orders/{order_id}", payload)
        
    async def delete_order(self, session):
        order_id = random.randint(1, 50)
        return await self.make_request(session, 'DELETE', f"{self.base_url}/api/orders/{order_id}")
        
    async def run_worker(self):
        async with aiohttp.ClientSession() as session:
            while True:
                operation = random.random()
                
                if operation < 0.5:
                    await self.get_all_orders(session)
                elif operation < 0.7:
                    await self.get_order(session)
                elif operation < 0.85:
                    await self.create_order(session)
                elif operation < 0.95:
                    await self.update_order(session)
                else:
                    await self.delete_order(session)
                    
                await asyncio.sleep(1 / self.target_rps)
                
    def print_stats(self):
        if not self.stats['latencies']:
            return
            
        latencies_sorted = sorted(self.stats['latencies'])
        p50 = latencies_sorted[len(latencies_sorted) // 2]
        p95 = latencies_sorted[int(len(latencies_sorted) * 0.95)]
        p99 = latencies_sorted[int(len(latencies_sorted) * 0.99)]
        
        error_rate = self.stats['failed_requests'] / self.stats['total_requests'] * 100 if self.stats['total_requests'] > 0 else 0
        
        print(f"\n📊 Load Test Statistics")
        print(f"{'='*50}")
        print(f"Total Requests: {self.stats['total_requests']}")
        print(f"Successful: {self.stats['successful_requests']}")
        print(f"Failed: {self.stats['failed_requests']}")
        print(f"Error Rate: {error_rate:.2f}%")
        print(f"\nLatency Percentiles:")
        print(f"  P50: {p50:.2f}ms")
        print(f"  P95: {p95:.2f}ms")
        print(f"  P99: {p99:.2f}ms")
        print(f"\nStatus Codes:")
        for status, count in sorted(self.stats['status_codes'].items()):
            print(f"  {status}: {count}")
            
    async def run(self, duration_seconds):
        print(f"🚀 Starting load test: {self.target_rps} RPS for {duration_seconds}s")
        print(f"Target URL: {self.base_url}")
        
        # Create workers based on target RPS
        num_workers = max(1, self.target_rps // 10)
        workers = [asyncio.create_task(self.run_worker()) for _ in range(num_workers)]
        
        # Print stats every 10 seconds
        start_time = time.time()
        while time.time() - start_time < duration_seconds:
            await asyncio.sleep(10)
            self.print_stats()
            
        # Cancel workers
        for worker in workers:
            worker.cancel()
            
        # Final stats
        print("\n🏁 Final Statistics:")
        self.print_stats()
        
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Load generator for Orders API')
    parser.add_argument('--url', default='http://localhost:8080', help='Base URL of the API')
    parser.add_argument('--rps', type=int, default=100, help='Target requests per second')
    parser.add_argument('--duration', type=int, default=600, help='Test duration in seconds')
    
    args = parser.parse_args()
    
    generator = LoadGenerator(args.url, args.rps)
    asyncio.run(generator.run(args.duration)) 