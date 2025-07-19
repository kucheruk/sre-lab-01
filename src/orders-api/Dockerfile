FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["orders-api.csproj", "."]
RUN dotnet restore "orders-api.csproj"
COPY . .
RUN dotnet build "orders-api.csproj" -c Release -o /app/build
RUN dotnet publish "orders-api.csproj" -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
EXPOSE 80
ENV ASPNETCORE_URLS=http://+:80
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "orders-api.dll"] 