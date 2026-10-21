# Casa do fim de semana

Três telas. As setas trocam o slide.

---

## Flutter

```dart
class Chegada extends StatelessWidget {
  const Chegada({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('A água subiu no filtro');
  }
}
```

---

## Kotlin

```kotlin
data class Recado(val origem: String, val texto: String)

fun avisar(casa: String): Recado {
    return Recado(casa, "nível ok")
}
```
