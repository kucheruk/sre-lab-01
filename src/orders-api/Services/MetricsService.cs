using Prometheus;
using System.Diagnostics;

public class MetricsService
{
    private readonly Histogram _requestDuration;
    private readonly Counter _requestTotal;

    public MetricsService()
    {
        _requestDuration = Metrics.CreateHistogram(
            "http_request_duration_seconds",
            "Duration of HTTP requests in seconds",
            new HistogramConfiguration
            {
                LabelNames = new[] { "method", "route", "status_code" },
                Buckets = Histogram.ExponentialBuckets(0.001, 2, 16) // 1ms to ~32s
            });

        _requestTotal = Metrics.CreateCounter(
            "http_requests_total",
            "Total number of HTTP requests",
            new CounterConfiguration
            {
                LabelNames = new[] { "method", "route", "status_code" }
            });
    }

    public void RecordRequest(string method, string route, int statusCode, double durationMs)
    {
        var durationSeconds = durationMs / 1000.0;
        var statusCodeStr = statusCode.ToString();

        _requestDuration.WithLabels(method, route, statusCodeStr).Observe(durationSeconds);
        _requestTotal.WithLabels(method, route, statusCodeStr).Inc();
    }
}