using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly OrdersService _ordersService;
    private readonly MetricsService _metrics;
    private readonly IConfiguration _configuration;
    private readonly Random _random = new();

    public OrdersController(OrdersService ordersService, MetricsService metrics, IConfiguration configuration)
    {
        _ordersService = ordersService;
        _metrics = metrics;
        _configuration = configuration;
    }

    [HttpGet]
    public async Task<IActionResult> GetOrders()
    {
        return await SimulateWorkWithChaos(async () =>
        {
            var orders = await _ordersService.GetOrdersAsync();
            return Ok(orders);
        }, "GET", "/api/orders");
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetOrder(int id)
    {
        return await SimulateWorkWithChaos(async () =>
        {
            var order = await _ordersService.GetOrderAsync(id);
            if (order == null)
                return NotFound();
            return Ok(order);
        }, "GET", "/api/orders/{id}");
    }

    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderRequest request)
    {
        return await SimulateWorkWithChaos(async () =>
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var order = await _ordersService.CreateOrderAsync(request);
            return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order);
        }, "POST", "/api/orders");
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateOrder(int id, [FromBody] UpdateOrderRequest request)
    {
        return await SimulateWorkWithChaos(async () =>
        {
            var order = await _ordersService.UpdateOrderAsync(id, request);
            if (order == null)
                return NotFound();
            return Ok(order);
        }, "PUT", "/api/orders/{id}");
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteOrder(int id)
    {
        return await SimulateWorkWithChaos(async () =>
        {
            var deleted = await _ordersService.DeleteOrderAsync(id);
            if (!deleted)
                return NotFound();
            return NoContent();
        }, "DELETE", "/api/orders/{id}");
    }

    private async Task<IActionResult> SimulateWorkWithChaos(Func<Task<IActionResult>> work, string method, string route)
    {
        var stopwatch = Stopwatch.StartNew();

        try
        {
            // Simulate chaos
            var errorRate = _configuration.GetValue<double>("Chaos:ErrorRate", 0.002);
            var slowRequestRate = _configuration.GetValue<double>("Chaos:SlowRequestRate", 0.05);
            var slowRequestDelay = _configuration.GetValue<int>("Chaos:SlowRequestDelayMs", 500);

            // Random errors (0.2% by default)
            if (_random.NextDouble() < errorRate)
            {
                _metrics.RecordRequest(method, route, 500, stopwatch.ElapsedMilliseconds);
                return StatusCode(500, new { error = "Internal server error", trace_id = Activity.Current?.TraceId.ToString() });
            }

            // Slow requests (5% by default)
            if (_random.NextDouble() < slowRequestRate)
            {
                await Task.Delay(slowRequestDelay);
            }

            // Normal processing delay (10-50ms)
            await Task.Delay(_random.Next(10, 50));

            var result = await work();
            var statusCode = GetStatusCode(result);
            _metrics.RecordRequest(method, route, statusCode, stopwatch.ElapsedMilliseconds);

            return result;
        }
        catch (Exception ex)
        {
            _metrics.RecordRequest(method, route, 500, stopwatch.ElapsedMilliseconds);
            return StatusCode(500, new { error = ex.Message, trace_id = Activity.Current?.TraceId.ToString() });
        }
    }

    private int GetStatusCode(IActionResult result)
    {
        return result switch
        {
            OkObjectResult => 200,
            CreatedAtActionResult => 201,
            NoContentResult => 204,
            BadRequestObjectResult => 400,
            NotFoundResult => 404,
            ObjectResult obj => obj.StatusCode ?? 200,
            StatusCodeResult status => status.StatusCode,
            _ => 200
        };
    }
}