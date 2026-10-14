# Clean Architecture Folder Structure Documentation

## Overview
This Flutter Android TV app follows Clean Architecture principles with clear separation of concerns and dependency inversion.

## Folder Structure

```
lib/
├── core/                          # Core functionality shared across the app
│   ├── constants/                 # App-wide constants
│   │   ├── api_constants.dart     # API URLs, endpoints, timeouts
│   │   └── app_constants.dart     # Colors, storage keys, app settings
│   ├── error/                     # Error handling
│   │   └── failures.dart          # Custom error classes (ServerFailure, NetworkFailure)
│   ├── network/                   # Network layer
│   │   └── api_client.dart        # Dio HTTP client with interceptors
│   └── di/                        # Dependency Injection
│       └── injection_container.dart # GetIt service locator setup
├── features/                      # Feature-based modules
│   └── logistics/                 # Logistics feature (sale orders)
│       ├── data/                  # Data layer (external concerns)
│       │   ├── datasources/       # Data sources (API, local storage)
│       │   │   └── logistics_remote_datasource.dart
│       │   ├── models/            # Data models (API response models)
│       │   │   └── sale_order_model.dart
│       │   └── repositories/      # Repository implementations
│       │       └── logistics_repository_impl.dart
│       ├── domain/                # Business logic layer (pure Dart)
│       │   ├── entities/          # Business entities
│       │   │   └── sale_order.dart
│       │   ├── repositories/      # Repository interfaces
│       │   │   └── logistics_repository.dart
│       │   └── usecases/          # Business use cases
│       │       └── get_sale_orders.dart
│       └── presentation/          # UI layer
│           ├── bloc/              # State management (BLoC)
│           │   ├── logistics_bloc.dart
│           │   ├── logistics_event.dart
│           │   └── logistics_state.dart
│           ├── pages/             # Screen widgets
│           │   └── logistics_screen.dart
│           └── widgets/           # Reusable UI components
│               └── job_board_item.dart
├── shared/                        # Shared utilities and widgets
│   ├── widgets/                   # Common UI components
│   └── utils/                     # Helper functions, extensions
└── main.dart                      # App entry point
```

## Layer Explanations

### 1. Core Layer (`core/`)
**Purpose**: Contains shared functionality used across the entire app.

- **constants/**: App-wide configuration values
- **error/**: Centralized error handling classes
- **network/**: HTTP client setup and configuration
- **di/**: Dependency injection container setup

### 2. Features Layer (`features/`)
**Purpose**: Contains feature-specific code organized by business domains.

Each feature follows the same structure:

#### Data Layer (`data/`)
- **datasources/**: External data sources (API calls, database operations)
- **models/**: Data transfer objects that match API responses
- **repositories/**: Concrete implementations of repository interfaces

#### Domain Layer (`domain/`)
- **entities/**: Pure business objects (no external dependencies)
- **repositories/**: Abstract interfaces for data access
- **usecases/**: Business logic operations

#### Presentation Layer (`presentation/`)
- **bloc/**: State management using BLoC pattern
- **pages/**: Full screen widgets
- **widgets/**: Feature-specific UI components

### 3. Shared Layer (`shared/`)
**Purpose**: Reusable components and utilities used across multiple features.

## Data Flow

```
UI (Presentation) → BLoC → UseCase → Repository Interface → Repository Implementation → DataSource → API
```

1. **UI** triggers events through BLoC
2. **BLoC** calls appropriate UseCase
3. **UseCase** executes business logic using Repository
4. **Repository** fetches data from DataSource
5. **DataSource** makes API calls
6. **Results** flow back through the same chain

## Key Benefits

### 1. Separation of Concerns
- Each layer has a single responsibility
- Business logic is isolated from UI and data sources
- Easy to test individual components

### 2. Dependency Inversion
- High-level modules don't depend on low-level modules
- Both depend on abstractions (interfaces)
- Easy to swap implementations (mock for testing)

### 3. Scalability
- New features follow the same pattern
- Code is organized and predictable
- Easy for team members to navigate

### 4. Testability
- Pure business logic in domain layer
- Easy to mock dependencies
- Clear boundaries for unit testing

## Example: Logistics Feature Flow

1. **User Action**: User opens logistics screen
2. **Presentation**: `LogisticsScreen` dispatches `LoadSaleOrders` event to `LogisticsBloc`
3. **BLoC**: Calls `GetSaleOrders` use case
4. **UseCase**: Validates input, calls `LogisticsRepository.getSaleOrders()`
5. **Repository**: Calls `LogisticsRemoteDataSource.getSaleOrders()`
6. **DataSource**: Makes HTTP request using `ApiClient`
7. **Response**: Data flows back, converted from models to entities
8. **UI Update**: BLoC emits new state, UI rebuilds with data

## File Naming Conventions

- **Entities**: `sale_order.dart`
- **Models**: `sale_order_model.dart`
- **Repositories**: `logistics_repository.dart` (interface), `logistics_repository_impl.dart` (implementation)
- **UseCases**: `get_sale_orders.dart`
- **BLoC**: `logistics_bloc.dart`, `logistics_event.dart`, `logistics_state.dart`
- **Screens**: `logistics_screen.dart`
- **Widgets**: `job_board_item.dart`

This structure ensures your Android TV app is maintainable, testable, and scalable for enterprise-level development.