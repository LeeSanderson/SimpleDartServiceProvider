// ignore_for_file: prefer_collection_literals, required to use LinkedHashMap to ensure items maintain order added

import 'dart:collection';

import './service_provider.dart';

typedef ServiceFactoryFunction<T> = Future<T> Function(ServiceProvider serviceProvider);

class ServiceContainer {
  final List<_ServiceRegistration<Object>> _services = [];
  final List<_ServiceRegistration<ServiceFactoryFunction<Object>>> _serviceFactories = [];
  ServiceProvider? _serviceProvider;

  ServiceContainer register<T>(T service, {String? id}) {
    _services.add(_ServiceRegistration<Object>(T, id, service as Object));
    _serviceProvider = null;
    return this;
  }

  ServiceContainer registerFactory<T>(ServiceFactoryFunction<T> factory, {String? id}) {
    _serviceFactories
        .add(_ServiceRegistration<ServiceFactoryFunction<Object>>(T, id, factory as ServiceFactoryFunction<Object>));
    _serviceProvider = null;
    return this;
  }

  Future<ServiceProvider> getServiceProvider() async => _serviceProvider ??= await _buildServiceProvider();

  Future<ServiceProvider> _buildServiceProvider() async {
    // Clone maps to avoid concurrent modifications.
    final services = LinkedHashMap<Type, List<_ServiceRegistration<Object>>>();
    for (final service in _services) {
      services.register(service.type, service);
    }

    final serviceProvider = _ServiceProvider(services);
    for (final serviceFactory in _serviceFactories) {
      final factoryRegistration = _ServiceRegistration<Object>(
        serviceFactory.type,
        serviceFactory.id,
        await serviceFactory.service(serviceProvider),
      );
      serviceProvider.register(serviceFactory.type, factoryRegistration);
    }

    return serviceProvider;
  }
}

class _ServiceRegistration<TService> {
  final Type type;
  final String? id;
  final TService service;

  _ServiceRegistration(this.type, this.id, this.service);
}

extension _RegisterService<TService> on Map<Type, List<TService>> {
  void register(Type key, TService service) {
    if (!containsKey(key)) {
      this[key] = [];
    }
    this[key]!.add(service);
  }
}

class _ServiceProvider extends ServiceProvider {
  final LinkedHashMap<Type, List<_ServiceRegistration<Object>>> _services;

  _ServiceProvider(this._services);

  void register(Type key, _ServiceRegistration<Object> service) {
    _services.register(key, service);
  }

  @override
  List<T> getAll<T>() {
    if (_services.containsKey(T)) {
      return _services[T]!.map((e) => e.service as T).toList();
    }

    throw Exception('No service found for type $T');
  }

  @override
  T get<T>({String? id}) {
    {
      if (!_services.containsKey(T)) {
        throw Exception('No service found for type $T');
      }

      final services = _services[T]!;
      if (services.isEmpty) {
        throw Exception('No service found for type $T');
      }

      final matchingServices = services.where((e) => e.id == id);
      if (matchingServices.isEmpty) {
        throw Exception('No service found for type $T and id $id');
      }

      if (matchingServices.length > 1) {
        throw Exception('Multiple services found for type $T and id $id');
      }

      return matchingServices.first.service as T;
    }
  }
}
