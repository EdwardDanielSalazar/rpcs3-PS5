# Auditoría inicial — RPCS3 nativo PS5 estándar, firmware 13.42

Fecha: 2026-10-20. Rama: `feature/ps5-13.42-rpcs3`.

## Alcance y estado

Auditoría estática del repositorio y de sus scripts; **no se ha compilado ni ejecutado en PS5 13.42**. El README documenta pruebas del autor en **PS5 Pro, firmware 13.60**, no en la PS5 estándar 13.42. Evitar declarar compatibilidad hasta tener una prueba en hardware real.

## Arquitectura verificada

- `src/rpcs3` es **submódulo**, apuntando al fork `lavavex/rpcs3`, rama `ps5`. No es el código de RPCS3 incorporado como archivos ordinarios al repositorio.
- Renderizador Vulkan mediante `PS5_Vulkan`/RADV; audio mediante SceAudioOut y mandos mediante ScePad, según README.
- `tools/bootstrap.sh` ejecuta: `fetch-deps`, `install-sdk`, `build-driver-chain`, `build-llvm`, zlib/libiconv/FFmpeg, base de configuraciones y `build-rpcs3`.
- `tools/fetch-deps.sh` fija revisiones concretas de `PS5_Vulkan`, `PS5_Mesa`, `PS5_PayloadSDK`, `PS5_LLVM`. **No actualizar pines de forma automática** durante las primeras pruebas.
- `tools/build-rpcs3.sh` utiliza CMake/Ninja, arquitectura Zen 2 (`-march=znver2`), LLVM y Vulkan. Los artefactos dependen del SDK y bibliotecas que construye bootstrap.
- `tools/link-title.sh` enlaza RADV, empaqueta `eboot.bin`, `sce_module/libc.prx` y recursos en `dist/PPSA99300`; también rechaza importaciones que no exporta ningún módulo cargado.
- `tools/deploy.sh` transfiere por FTP la carpeta a `/data/homebrew/PPSA99300` y presupone que ShadowMount+ publique el título.

## Riesgos técnicos identificados

1. **Modelo de memoria y JIT:** `docs/PS5_MEMORY_NOTES.md` explica por qué `mmap` ordinario no basta en títulos nativos, el uso de memoria directa y alias, reservas virtuales de 4–32 GiB, páginas de 16 KiB y acceso ejecutable a memoria JIT. Documentación existente, no prueba de compatibilidad para 13.42.
2. **GPU:** mantener las reservas del emulador alejadas de la ventana de RADV indicada en las notas (0x200000000–0x300000000). Fallos de Vulkan se deben diagnosticar con registros, no atribuir automáticamente al firmware.
3. **Dependencias:** los scripts dependen de clones fijados y herramientas de compilación Linux; antes de cambiar CMake, hay que demostrar que las dependencias se descargan y se compilan.
4. **Compatibilidad y estabilidad:** el README indica que el autor solo probó un conjunto pequeño de juegos y advierte sobre cierres y bloqueos. No usar Ascension como primera prueba de arranque.
5. **Licencias:** el README advierte de incompatibilidades de redistribución de binarios combinados. Mantener los resultados de compilación para uso privado; no publicar `eboot.bin` ni firmware ni juegos.

## Plan de validación por fases

### Fase A — reproducibilidad del host
- Clonar la **rama de trabajo** incluyendo submódulos.
- Registrar SO, arquitectura, versiones de Clang/CMake/Ninja/Python y espacio libre.
- Ejecutar comprobación de herramientas de `bootstrap.sh` y `tools/fetch-deps.sh`; registrar SHAs y resultados.
- Confirmar que todos los pines coinciden con `PINS.md`.

### Fase B — compilación idéntica a origen
- Construir sin cambios funcionales con `tools/bootstrap.sh`.
- Registrar primer error reproducible (si ocurre) y guardar log completo.
- Comprobar que `dist/PPSA99300/eboot.bin`, `sce_sys/param.json` y `sce_module/libc.prx` están presentes.
- No afirmar éxito hasta que `self --inspect` y empaquetado concluyan.

### Fase C — primera ejecución en PS5 estándar 13.42
- Hacer copia de `/data/rpcs3/` si ya existe y detener títulos en ejecución antes de transferir.
- Publicar únicamente en `/data/homebrew/PPSA99300` usando ShadowMount+.
- Probar arranque del menú **sin juegos**. Registrar si aparece, responde al mando y sale correctamente.
- Recuperar `/data/rpcs3/cache/RPCS3.log` inmediatamente si se cierra; cada ejecución puede sobrescribirlo.
- Separar errores de carga de módulos, reserva/JIT, Vulkan, interfaz y lectura de archivos.

### Fase D — pruebas funcionales
- Instalar firmware PS3 oficial obtenido legítimamente; probar primero una carga pequeña y conocida.
- Medir estabilidad, FPS, tiempos de compilación PPU/SPU, uso de memoria y errores.
- Probar juegos exigentes (incluido God of War: Ascension) **solo** después del arranque reproducible.

## Criterios antes de editar código

Solo introducir cambios cuando exista un fallo reproducible con archivo y línea identificados; documentar hipótesis, cambio mínimo y resultado. No introducir offsets, llamadas kernel o diferencias entre PS5 Pro/estándar sin evidencia. `main` permanece sin cambios.

## Fuentes internas revisadas

`README.md`, `PINS.md`, `.gitmodules`, `tools/bootstrap.sh`, `tools/fetch-deps.sh`, `tools/build-rpcs3.sh`, `tools/link-title.sh`, `tools/deploy.sh`, `cmake/ps5-rpcs3.cmake`, `docs/PS5_MEMORY_NOTES.md`.
