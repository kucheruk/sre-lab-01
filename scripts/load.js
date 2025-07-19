import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: __ENV.K6_RPS || 100 }, // Ramp up
    { duration: '10m', target: __ENV.K6_RPS || 100 }, // Stay at target RPS
    { duration: '30s', target: 0 }, // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    errors: ['rate<0.1'], // Error rate must be below 10%
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

// Test data
const customers = ['CUST001', 'CUST002', 'CUST003', 'CUST004', 'CUST005'];
const products = Array.from({ length: 20 }, (_, i) => `PROD${String(i + 1).padStart(3, '0')}`);

export default function () {
  // Randomly choose an operation
  const operation = Math.random();
  
  if (operation < 0.5) {
    // 50% - Get all orders
    getAllOrders();
  } else if (operation < 0.7) {
    // 20% - Get specific order
    getOrder();
  } else if (operation < 0.85) {
    // 15% - Create new order
    createOrder();
  } else if (operation < 0.95) {
    // 10% - Update order
    updateOrder();
  } else {
    // 5% - Delete order
    deleteOrder();
  }
  
  sleep(1 / (__ENV.K6_RPS || 100)); // Control request rate
}

function getAllOrders() {
  const response = http.get(`${BASE_URL}/api/orders`);
  const success = check(response, {
    'Get all orders - status is 200': (r) => r.status === 200,
    'Get all orders - has orders': (r) => JSON.parse(r.body).length > 0,
  });
  errorRate.add(!success);
}

function getOrder() {
  const orderId = Math.floor(Math.random() * 20) + 1;
  const response = http.get(`${BASE_URL}/api/orders/${orderId}`);
  const success = check(response, {
    'Get order - status is 200 or 404': (r) => r.status === 200 || r.status === 404,
  });
  errorRate.add(!success);
}

function createOrder() {
  const customerId = customers[Math.floor(Math.random() * customers.length)];
  const itemCount = Math.floor(Math.random() * 3) + 1;
  const items = [];
  
  for (let i = 0; i < itemCount; i++) {
    items.push({
      productId: products[Math.floor(Math.random() * products.length)],
      quantity: Math.floor(Math.random() * 5) + 1,
      price: Math.floor(Math.random() * 90) + 10,
    });
  }
  
  const payload = JSON.stringify({
    customerId: customerId,
    items: items,
  });
  
  const params = {
    headers: { 'Content-Type': 'application/json' },
  };
  
  const response = http.post(`${BASE_URL}/api/orders`, payload, params);
  const success = check(response, {
    'Create order - status is 201': (r) => r.status === 201,
    'Create order - has order ID': (r) => JSON.parse(r.body).id > 0,
  });
  errorRate.add(!success);
}

function updateOrder() {
  const orderId = Math.floor(Math.random() * 20) + 1;
  const statuses = ['Pending', 'Processing', 'Shipped', 'Delivered'];
  const payload = JSON.stringify({
    status: statuses[Math.floor(Math.random() * statuses.length)],
  });
  
  const params = {
    headers: { 'Content-Type': 'application/json' },
  };
  
  const response = http.put(`${BASE_URL}/api/orders/${orderId}`, payload, params);
  const success = check(response, {
    'Update order - status is 200 or 404': (r) => r.status === 200 || r.status === 404,
  });
  errorRate.add(!success);
}

function deleteOrder() {
  const orderId = Math.floor(Math.random() * 50) + 1; // Higher range to test 404s
  const response = http.del(`${BASE_URL}/api/orders/${orderId}`);
  const success = check(response, {
    'Delete order - status is 204 or 404': (r) => r.status === 204 || r.status === 404,
  });
  errorRate.add(!success);
} 