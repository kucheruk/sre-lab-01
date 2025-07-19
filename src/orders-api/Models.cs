using System;
using System.Collections.Generic;

public class Order
{
    public int Id { get; set; }
    public string CustomerId { get; set; } = "";
    public List<OrderItem> Items { get; set; } = new();
    public string Status { get; set; } = "Pending";
    public decimal Total { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public class OrderItem
{
    public string ProductId { get; set; } = "";
    public int Quantity { get; set; }
    public decimal Price { get; set; }
}

public class CreateOrderRequest
{
    public string CustomerId { get; set; } = "";
    public List<OrderItem> Items { get; set; } = new();
}

public class UpdateOrderRequest
{
    public string? Status { get; set; }
    public List<OrderItem>? Items { get; set; }
}