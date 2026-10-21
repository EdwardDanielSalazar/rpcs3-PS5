# Auditoría del cargador de objetos PPU LLVM

Fecha: 2026-10-20. Rama: `feature/ps5-13.42-rpcs3`.

## Código comprobado

Fuente: `lavavex/rpcs3` (`ps5`), archivo `Utilities/JITLLVM.cpp`.

- `ObjectCache::load(path)` (~500–540) intenta primero `path + ".gz"` y descomprime, y después `path` sin comprimir. Rechaza buffers vacíos.
- El guardado de objetos usa `zip(...)` y `fs::pending_file`, con commit del archivo después de una escritura exitosa (~465–495).
- `jit_compiler::check(path)` (~928–945) solo carga bytes y comprueba que `llvm::object::ObjectFile::createObjectFile` los interprete como un objeto. **No consta aquí una comprobación explícita de triple, ABI, arquitectura, símbolos requeridos ni versión LLVM**.
- `jit_compiler::add(path)` (~905–926) vuelve a cargar el objeto y lo pasa a `m_engine->addObjectFile(...)`. Que `check()` dé true no garantiza que el enlace dinámico o ejecución posterior tengan éxito.
- `rpcs3/Emu/Cell/PPUThread.cpp` (~5530–5615) nombra objetos con formato `v8-kusa-<hash>-<settings>-<cpu>.obj` y comprueba la caché con `jit_compiler::check(cache_path + obj_name)`.

## Consecuencias para precompilación externa

**No copiar cachés de RPCS3 desktop a PS5 sin validación**. Una comprobación sintáctica de objeto no basta para compatibilidad de ISA, ABI, símbolos o configuración. El nombre incorpora CPU y ajustes pero no necesariamente todos los parámetros relevantes; el código del generador tiene un TODO al respecto.

Próximas validaciones recomendadas:
1. Leer `jit_compiler::triple1()`, `triple2()` y `cpu()` y el uso específico del compilador de PS5.
2. Comprobar tipo de objeto/arquitectura y símbolos contra un artefacto producido por el port original, **una vez compilado**.
3. Diseñar informe de preflight para objetos (solo lectura), sin reemplazar `check()` en producción.
4. Medir tasa de aciertos/fallos y tiempo de generación/carga de caché con instrumentación optativa, y comparar contra base reproducible.
5. Registrar el primer log de arranque en PS5 estándar 13.42 antes de atribuir problemas a la caché.

## Estado

Auditado estáticamente; no se ha generado ni ejecutado `eboot.bin`; ninguna mejora está medida. No se cambia ni el submódulo RPCS3 ni los archivos de caché.
