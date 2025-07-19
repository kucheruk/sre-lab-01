using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

public class OrdersService
{
    private readonly Dictionary<int, Order> _orders = new();
    private int _nextId = 1;
    private readonly SemaphoreSlim _lock = new(1, 1);

    public OrdersService()
    {
        // Seed some data
        for (int i = 1; i <= 10; i++)
        {
            _orders[i] = new Order
            {
                Id = i,
                CustomerId = $"CUST{i:000}",
                Items = GenerateItems(Random.Shared.Next(1, 5)),
                Status = "Pending",
                CreatedAt = DateTime.UtcNow.AddHours(-Random.Shared.Next(1, 48)),
                Total = Random.Shared.Next(50, 500)
            };
            _nextId = i + 1;
        }
    }

    public async Task<List<Order>> GetOrdersAsync()
    {
        await _lock.WaitAsync();
        try
        {
            return _orders.Values.OrderByDescending(o => o.CreatedAt).ToList();
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<Order?> GetOrderAsync(int id)
    {
        await _lock.WaitAsync();
        try
        {
            return _orders.TryGetValue(id, out var order) ? order : null;
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<Order> CreateOrderAsync(CreateOrderRequest request)
    {
        await _lock.WaitAsync();
        try
        {
            var order = new Order
            {
                Id = _nextId++,
                CustomerId = request.CustomerId,
                Items = request.Items,
                Status = "Pending",
                CreatedAt = DateTime.UtcNow,
                Total = request.Items.Sum(i => i.Price * i.Quantity)
            };
            _orders[order.Id] = order;
            return order;
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<Order?> UpdateOrderAsync(int id, UpdateOrderRequest request)
    {
        await _lock.WaitAsync();
        try
        {
            if (!_orders.TryGetValue(id, out var order))
                return null;

            order.Status = request.Status ?? order.Status;
            if (request.Items != null)
            {
                order.Items = request.Items;
                order.Total = request.Items.Sum(i => i.Price * i.Quantity);
            }
            order.UpdatedAt = DateTime.UtcNow;

            return order;
        }
        finally
        {
            _lock.Release();
        }
    }

    public async Task<bool> DeleteOrderAsync(int id)
    {
        await _lock.WaitAsync();
        try
        {
            return _orders.Remove(id);
        }
        finally
        {
            _lock.Release();
        }
    }

    private List<OrderItem> GenerateItems(int count)
    {
        var items = new List<OrderItem>();
        for (int i = 0; i < count; i++)
        {
            items.Add(new OrderItem
            {
                ProductId = $"PROD{Random.Shared.Next(1, 100):000}",
                Quantity = Random.Shared.Next(1, 5),
                Price = Random.Shared.Next(10, 100)
            });
        }
        return items;
    }
}