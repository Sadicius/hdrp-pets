
# Changelog

## [6.7.3] - 2026-01-28
### Refactor y robustez de estados
- Solucionando problemas localizados en testeos. Todavia requeire de mas pruebas
- Problemas identificados con el sistema de rastreo
- Problemas con buried, hostiles, bandit y tesoro
- Problemas con los logros no identifica a la mascota
- Problemas en breeding
- Limpieza de configuraciones obsoletas u inexistentes
- Traslado de funciones a utilts_spawn
- Adicion de textos a locales

## [6.6.8] - 2026-01-25
### Refactor y robustez de estados
- Refactor completo de la gestión de modos principales de mascota: ahora todos los modos (wandering, herding, hunting, game, following, track) son exclusivos y se gestionan solo mediante el helper State.SetPetMainMode.
- Eliminadas todas las asignaciones directas de flags principales en el código de minijuegos, herding, prompts y wandering.
- Integración de State.SetPetMainMode en todos los flujos relevantes (wandering, herding, hunting, minijuegos bone y buried).
- Auditoría y revisión exhaustiva de todos los subestados (isRetrieving, isFrozen, isInCombat, isDead, isCritical, isBreeding, isRetrieved, isCustomizing, isVeterinary):
	- Confirmado que todos los subestados activos son temporales, bien aislados y no generan conflictos ni inconsistencias.
	- Los subestados inactivos (isCustomizing, isVeterinary) no presentan riesgos.
- El sistema de flags secundarios y principales es ahora robusto, realista y seguro para entornos multijugador.
- Documentación y checklist de consistencia actualizados.

## [6.6.7] - 2026-01-23
### Añadido
- Modificado toda la parte server, ya esta refactorizado para el nuevo sistema.
- Se ha realizado limpieza de funciones no necesarias y codigos redundantes.
- Se ha unificado para mejor uso de core/Database
- Se ha reconstruido el fight y breeding para el nuevo sistema refactorizado con columna independiente
- Se ha modficado la tabla sql principal
- Se han trasladado todos los callbaks que estaban fuera de core/callbaks a su interior
- Otros

### IMPORTANTE PENDIENTE TODAVIA TODA LA PARTE CLIENT PARA EL NUEVO FORMATO DE DATOS

## [6.6.6] - 2026-01-21
### Añadido
- Modificacion importante reduccion de anidamiento State.Pets.active a State.Pets
- Se elimina el archivo /server/systems/commands.lua, se han movido a trade.lua y a items.lua los comandos

## [6.6.5] - 2026-01-21
### Añadido
- Refactorizacion de menu archievements, stats, quickcare.
- Menos código repetido, Más fácil de mantener y escalar.
- cambio localizacion de menus a carpeta client/menu, se deja stable menu y bettings menu separados 

- añadido locales en json

## [6.6.4] - 2026-01-21
### Añadido
- Deteccion y aviso a policia en apuestas y peleas
- añadido locales en json

## [6.6.3] - 2026-01-20
### Añadido
- Solucionado el problema de apuestas
- Solucionado problema en menu de logros (pensar si es la mejor forma de verlos, de momento es valida)
- solucionado el problema de breending error de sintaxis.

## [6.6.2] - 2026-01-20
### Añadido
- Sistema de apuestas y sistema de lucha para enfrentamiento de mascotas `Fight`
- Variable `Strength`, para los combates. Añadido a los menus, decay y metadata

## [6.6.0] - 2026-01-20
### Añadido
- Permitir usar mascotas propias en el minijuego de pelea: ahora el sistema acepta mascotas activas del jugador (State.Pets.active) como participantes, además de perros generados por modelo.
- Variantes de combate: soporte para mascota vs NPC, mascota vs mascota (mismo jugador), y mascota vs mascota (jugador vs jugador).
- Logros y XP de combate: los logros y la experiencia obtenida en peleas se actualizan y se guardan en la base de datos usando el campo `companiondata`.
- Integración con menú de logros: los logros y XP de combate se muestran correctamente en el menú de achievements de cada mascota.
- Notificaciones de logros y combate: se envían al cliente usando `lib.notify` y eventos dedicados.
### Cambiado
- Refactor de la lógica de persistencia para logros y XP, usando el API centralizado de base de datos (`Database.UpdateCompanionData`).
- Mejoras en la modularidad del sistema de peleas y en la integración con el menú de apuestas.


## [6.5.9] - 2026-01-18
### Añadido
- Auditoría completa de variables, funciones, eventos, menús y elementos clave del proyecto, documentada en docs/.
- Inclusión y revisión de todos los logros (achievements) definidos en la configuración, asegurando su presencia en el menú de achievements.
- Metadata y requisitos visibles en menús de formaciones y logros.
### Cambiado
- Refactor y mejora de la lógica de menús de achievements y herding para mayor claridad y completitud.
- Actualización de la documentación y sincronización de la configuración de logros con la interfaz de usuario.


Este changelog unifica y resume todos los cambios relevantes del proyecto, siguiendo la filosofía de [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y [SemVer](https://semver.org/lang/es/). La historia completa, incluyendo logs antiguos y detalles exhaustivos de versiones previas a la serie 6.x, está curada y consolidada en este archivo y en los históricos de `docs/old/`.

---

## [6.5.8] - 2026-01-18
### Añadido
- Unificación y curación del changelog histórico en un solo archivo, siguiendo el estándar Keep a Changelog.
- Proceso de migración y documentación de logs antiguos en `docs/old/`.
- Mejoras en la estructura y claridad del changelog para usuarios y desarrolladores.
- Nuevas formaciones avanzadas en el sistema de herding.

### Cambiado
- Limpieza y reestructuración de múltiples archivos del proyecto.
- Unificación y reubicación de funciones en el módulo State y otros módulos clave.
- Revisión y ordenamiento de menús, opciones y eventos asociados.
- Mejoras en la lógica y experiencia de breeding.
- Estandarización y actualización de la documentación de cambios.

---

## [6.1.3] - 2026-01-16
### Cambiado
- Limpieza de claves no usadas en locales (`es.json`).

## [6.1.2] - 2026-01-16
### Añadido
- Metadata ampliada en menús principales: establo, gestión, veterinario, dashboard y stats.
- Visualización de estado veterinario, fechas de vacunación, cirugía y esterilización en menús.
- Resumen veterinario en Quick Care para acciones masivas.
- Visualización de raza y color en metadata de mascota.
### Cambiado
- Refactor y unificación de presentación de información en menús de mascotas.
### Corregido
- Correcciones menores de consistencia visual y de datos en menús.

## [6.1.1] - 2026-01-16
### Añadido
- Auditoría y traducción de locales (`es.json`, `en.json`).
- Integración de menús de mascotas con ox_target y prompts.
- Sistemas de inventario, tienda, y caza con prompts y notificaciones localizadas.
- Multipet hunt mode y optimizaciones de prompts.
- Persistencia unificada de customización y props en JSON único por mascota.
- Documentación y guías de test para todos los sistemas principales.
### Cambiado
- Optimización de lookup de petId en prompts.
- Refactor de customize.lua y attachment.lua para persistencia unificada.
- Flujos de menú mejorados para multi-mascota.
### Corregido
- Corrección de inconsistencias en prompts y notificaciones.
- Solución a problemas de persistencia de props y selección multi-mascota.

## [6.1.0] - 2026-01-16
### Añadido
- Lanzamiento inicial de hdrp-pets con sistemas core, menús, minijuegos, inventario, herding y personalización.
- Gestión multipet, XP, logros, comercio, veterinario, breeding, tracking y persistencia robusta.

---

## [6.0.x] - 2026-01-11 al 2026-01-14
### Añadido
- Rediseño completo de arquitectura de menús y sistema modular UI.
- Dashboard centralizado, Quick Actions, sistema de logros y minijuegos.
- Menú de establo independiente para NPCs.
- Soporte multipet completo en todos los sistemas y helpers.
- Sistema de decay, lifecycle, XP, achievements y party XP sharing.
- Sistema de consumibles y configuración avanzada.
### Cambiado
- Refactor de todos los sistemas para eliminar legacy y duplicados.
- Limpieza y migración de menús antiguos a `client/ui/old/`.
- Unificación de helpers y eventos para multipet.
### Corregido
- Corrección de bugs críticos en menús, comandos y persistencia.
- Limpieza de memory leaks y referencias legacy.

---

## [5.8.x] - 2026-01-10 al 2026-01-11
### Añadido
- Party XP sharing, sistema de achievements y notificaciones de level up.
- Integración de minijuegos con soporte multipet y competencia.
- Localización completa de módulos y mensajes de sistema.
- Auditoría completa para eliminar variables legacy y globales.
### Cambiado
- Refactor de prompts, helpers y menús para arquitectura multipet.
- Unificación de patrones de carga y organización de carpetas.
### Corregido
- Corrección de bugs críticos en State.GetPet(), menús y comandos.
- Limpieza de props, memory leaks y errores de naming.

---


## [Historial previo a 2026]
Todo el historial detallado de versiones 1.x a 5.x, así como logs técnicos y análisis de arquitectura, se encuentra curado en los archivos:
- `docs/old/CHANGELOG_v1.md` (historial extenso, análisis y migraciones)
- `docs/old/CHANGELOG_v2.md` (estructura Keep a Changelog, versiones 6.1.x y previas)

La información relevante de estos logs ha sido integrada y resumida en este changelog principal para facilitar la consulta y el mantenimiento.

---

## Notas de migración y arquitectura
- El sistema multipet y la arquitectura modular UI se consolidaron en la serie 6.x.
- Todo el código legacy fue eliminado o marcado para referencia, garantizando mantenibilidad y escalabilidad.
- La documentación de test y auditoría se encuentra en `docs/`.

---

> Este changelog es curado y legible para humanos. Cada entrada resume los cambios relevantes para usuarios y desarrolladores. Para detalles técnicos, consulta la documentación histórica.
