abstract class ServiceProvider {
  T get<T>({String? id});

  List<T> getAll<T>();
}
