# Лабораторная работа 1: Определение SLI/SLO

Данный репозиторий содержит полную инфраструктурную настройку для Лабораторной работы 1 по курсу "Инженерия надежности".

## Предварительные требования

- Docker Desktop или Docker Engine
- k3d (v5.x)
- kubectl (v1.27+)
- k6 (для нагрузочного тестирования)
- Git
- Как минимум 8GB доступной RAM
- Свободные порты 3000, 8080, 9090, 16686

## Настройка macOS (с нуля)

Если вы начинаете с чистой системы macOS, следуйте этим шагам для подготовки окружения:

### Автоматическая настройка

Запустите наш скрипт настройки для установки всех зависимостей:
```bash
./scripts/setup-macos.sh
```

### Шаги ручной настройки

1. **Установка Xcode Command Line Tools** (требуется для Homebrew):
   ```bash
   xcode-select --install
   ```

2. **Установка Homebrew** (если отсутствует):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
   eval "$(/opt/homebrew/bin/brew shellenv)"
   ```

3. **Установка зависимостей**:
   ```bash
   # Основные инструменты
   brew install --cask docker
   brew install k3d kubectl k6
   
   # Опциональные, но рекомендуемые
   brew install git curl wget jq
   ```

4. **Запуск Docker Desktop**:
   - Запустите Docker Desktop из папки Applications
   - Дождитесь запуска Docker (проверьте статус в меню)
   - Убедитесь, что Docker выделено как минимум 4GB RAM

5. **Проверка установки**:
   ```bash
   ./scripts/check-environment.sh
   ```

### Системные требования

- **macOS**: 12.0+ (Monterey или новее)
- **RAM**: 16GB рекомендуется (8GB минимум)
- **Хранилище**: 10GB свободного места
- **Сеть**: Подключение к интернету для загрузок

## Быстрый старт

### Для новых систем macOS

1. **Клонирование репозитория**:
   ```bash
   git clone <repository-url>
   cd lab1-stand
   ```

2. **Подготовка окружения macOS** (пропустите, если инструменты уже установлены):
   ```bash
   ./scripts/setup-macos.sh
   ```

3. **Проверка окружения**:
   ```bash
   ./scripts/check-environment.sh
   ```

4. **Настройка кластера**:
   ```bash
   ./scripts/setup-cluster.sh
   ```

5. **Проверка работоспособности**:
   ```bash
   ./scripts/verify-setup.sh
   ```

### Для систем с уже установленными зависимостями

1. Клонирование репозитория:
   ```bash
   git clone <repository-url>
   cd lab1-stand
   ```

2. Проверка окружения и настройка кластера:
   ```bash
   ./scripts/check-environment.sh
   ./scripts/setup-cluster.sh
   ./scripts/verify-setup.sh
   ```

## Архитектура

Лабораторное окружение состоит из:

- **Orders API**: Микросервис на .NET 8 с контролируемым внедрением хаоса
- **Prometheus**: Сбор и хранение метрик
- **Grafana**: Визуализация и дашборды SLO
- **Jaeger**: Распределенная трассировка (опционально для Лабораторной 1)
- **OpenTelemetry Collector**: Конвейер телеметрии

## URL сервисов

После настройки сервисы доступны по адресам:

- Orders API: http://localhost:8080
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/lab1pass)
- Jaeger: http://localhost:16686

## Запуск нагрузочных тестов

Базовый нагрузочный тест (100 RPS в течение 10 минут):
```bash
K6_RPS=100 k6 run scripts/load.js
```

Пользовательские параметры:
```bash
K6_RPS=200 BASE_URL=http://localhost:8080 k6 run scripts/load.js
```

Альтернативный Python генератор нагрузки:
```bash
python3 src/load-generator/generator.py --rps 100 --duration 600
```

## Конфигурация хаоса

Orders API включает настраиваемое внедрение хаоса:

- **Частота ошибок**: 0.2% (настраивается через CHAOS_ERROR_RATE)
- **Медленные запросы**: 5% с задержкой 500ms (настраивается)

Изменения вносятся в `k8s/orders-api/configmap.yaml` с перезапуском подов.

## Доступные метрики

Orders API предоставляет следующие метрики Prometheus:

- `http_request_duration_seconds` - Гистограмма латентности запросов
- `http_requests_total` - Счетчик запросов с кодами состояния

Метки: `method`, `route`, `status_code`

## Задания лабораторной работы

1. Запустить нагрузочный тест и изучить базовые метрики
2. Определить формулы SLI в PromQL
3. Установить реалистичные целевые показатели SLO
4. Рассчитать бюджет ошибок
5. Создать дашборд Grafana с линиями SLO
6. Задокументировать в файле `SLO.md`

## Устранение неполадок

### Проблемы с Port Forward
Если port forward соединения разорваны, перезапустите их:
```bash
pkill -f "kubectl port-forward"
kubectl port-forward -n lab1 svc/orders-api 8080:80 &
kubectl port-forward -n lab1 svc/prometheus 9090:9090 &
kubectl port-forward -n lab1 svc/grafana 3000:3000 &
```

### Метрики не отображаются
1. Проверьте, что поды запущены: `kubectl get pods -n lab1`
2. Проверьте endpoint метрик: `curl http://localhost:8080/metrics`
3. Проверьте targets в Prometheus: http://localhost:9090/targets

### Высокая частота ошибок
Базовая частота ошибок намеренно установлена на ~0.2%. Это настраивается в ConfigMap.

## Очистка

Для полного удаления лабораторного окружения:
```bash
./scripts/cleanup.sh
```

## Структура директорий

```
lab1-stand/
├── k8s/                    # Kubernetes манифесты
│   ├── namespace.yaml
│   ├── orders-api/        # Конфигурации развертывания API
│   └── monitoring/        # Стек наблюдаемости
├── src/
│   ├── orders-api/        # Код сервиса .NET 8
│   └── load-generator/    # Python инструмент нагрузочного тестирования
├── scripts/               # Скрипты настройки и утилиты
├── dashboards/            # Шаблоны дашбордов Grafana
└── README.md
```

## Следующие шаги

После завершения Лабораторной работы 1 у вас должно быть:
- ✅ Базовые метрики производительности
- ✅ Определенные формулы SLI
- ✅ Установленные реалистичные целевые показатели SLO
- ✅ Рассчитанный бюджет ошибок
- ✅ Созданный дашборд мониторинга

Эти результаты будут использованы в Лабораторной работе 2 для создания production-ready SLO дашбордов. 