# Weekend house

Three slides. The arrow keys change the slide.

---

## Flutter

```dart
class Arrival extends StatelessWidget {
  const Arrival({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('The water rose in the filter');
  }
}
```

---

## Kotlin

```kotlin
data class Note(val origin: String, val text: String)

fun notify(house: String): Note {
    return Note(house, "level ok")
}
```
