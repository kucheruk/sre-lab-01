using System.Diagnostics;
using System.Diagnostics.Metrics;
using Microsoft.AspNetCore.Mvc;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

// Configure OpenTelemetry
var serviceName = builder.Configuration["Otlp:ServiceName"] ?? "orders-api";
var serviceVersion = builder.Configuration["Otlp:ServiceVersion"] ?? "1.0.0";
var otlpEndpoint = builder.Configuration["Otlp:Endpoint"] ?? "http://otel-collector:4317";

builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(serviceName: serviceName, serviceVersion: serviceVersion))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri(otlpEndpoint);
        }))
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddRuntimeInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter(otlpOptions =>
        {
            otlpOptions.Endpoint = new Uri(otlpEndpoint);
        }));

// Add services
builder.Services.AddControllers();
builder.Services.AddHealthChecks();
builder.Services.AddSingleton<OrdersService>();
builder.Services.AddSingleton<MetricsService>();

var app = builder.Build();

// Configure middleware
app.UseRouting();
app.UseHttpMetrics(); // Prometheus metrics
app.MapMetrics(); // Prometheus /metrics endpoint
app.MapControllers();
app.MapHealthChecks("/health");
app.MapHealthChecks("/ready");

app.Run();