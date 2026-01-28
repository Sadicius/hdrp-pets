# HDRP-PETS - Informe de Problemas Detectados

**Fecha de Revision:** 2026-01-28
**Version Revisada:** 6.7.3

---

## Resumen Ejecutivo

| Categoria | Criticos | Altos | Medios | Bajos |
|-----------|----------|-------|--------|-------|
| Cliente (client/) | 0 | 14 | 15 | 5 |
| Servidor (server/) | 5 | 18 | 12 | 1 |
| Compartidos (shared/) | 1 | 0 | 1 | 4 |
| Manifest/Instalacion | 1 | 1 | 0 | 1 |
| **TOTAL** | **7** | **33** | **28** | **11** |

---

## 1. PROBLEMAS CRITICOS (Requieren atencion inmediata)

### 1.1 Archivo de servidor no cargado en fxmanifest.lua
- **Archivo:** `fxmanifest.lua`
- **Problema:** El archivo `server/systems/xp.lua` existe pero **NO esta incluido** en `server_scripts`
- **Impacto:** El sistema de XP del servidor nunca se ejecuta
- **Solucion:** Agregar `'server/systems/xp.lua'` a la seccion `server_scripts`

### 1.2 MySQL.update sin .await (Multiples archivos)
- **Archivos afectados:**
  - `server/core/database.lua` lineas 267, 283
  - `server/systems/customize.lua` linea 31
  - `server/systems/fight.lua` lineas 371, 373, 419, 421
  - `server/systems/trade.lua` lineas 371, 373, 419, 421
- **Problema:** `MySQL.update` llamado sin `.await` - retorna promesa en lugar de ejecutar
- **Impacto:** Las actualizaciones de base de datos no se ejecutan correctamente

### 1.3 Wait() bloqueante en event handler
- **Archivo:** `server/main.lua` linea 388
- **Problema:** `Wait(1000)` dentro de `AddEventHandler('hdrp-pets:server:setrip')` bloquea el thread
- **Impacto:** Puede causar fallos en cascada del servidor

### 1.4 Vulnerabilidad SQL Injection - Input del cliente
- **Archivo:** `server/systems/fight.lua` lineas 217, 246, 306
- **Problema:** `outlawstatus` viene del evento del cliente y se usa directamente en UPDATE SQL
- **Impacto:** Posible inyeccion SQL desde cliente malicioso

### 1.5 Carga incorrecta de modulos (require en lugar de lib.load)
- **Archivo:** `server/systems/fight.lua` lineas 5-6
- **Problema:** Usa `require('server.core.database')` y `require('shared.game.games')` que no funcionan en FX framework
- **Impacto:** El archivo no cargara correctamente

---

## 2. PROBLEMAS DE ALTA SEVERIDAD

### 2.1 Funciones indefinidas en cliente

| Archivo | Linea | Funcion |
|---------|-------|---------|
| `client/games/fight.lua` | 33 | `ApplyEffectiveDogDamage()` |
| `client/stable/call.lua` | 301, 304 | `StopPetWandering()` |
| `client/stable/call.lua` | 340 | `GetPetHerdingState()` |
| `client/stable/call.lua` | 341 | `ResumePetHerding()` |
| `client/stable/call.lua` | 343 | `SetupPetHerding()` |
| `client/stable/call.lua` | 348 | `SetupPetWandering()` |
| `client/state.lua` | 357-358 | `GetMaxAttributePoints()`, `GetAttributePoints()` |

### 2.2 Variables indefinidas en cliente

| Archivo | Linea | Variable |
|---------|-------|----------|
| `client/stable/pets.lua` | 555 | `info` (deberia ser `petData.data.info`) |
| `client/stable/pets.lua` | 557 | `progression` |
| `client/games/bone.lua` | 247 | `closestPet.companionid` |

### 2.3 Variables indefinidas en servidor

| Archivo | Linea | Variable |
|---------|-------|----------|
| `server/systems/management.lua` | 158 | `Gtreasure` (deberia ser `gameTreasureConfig`) |
| `server/systems/veterinary.lua` | 277 | `petId` (parametro es `companionid`) |
| `server/systems/fight.lua` | 187 | `outlawstatus` |
| `server/core/callbacks.lua` | 110 | `pet.data` tipo incorrecto |

### 2.4 Errores logicos en condiciones

**Archivo:** `client/menu/menu_stable.lua` linea 614
```lua
-- INCORRECTO:
if vet.isvaccinated and vet.vaccineexpire and (not vet.vaccineexpire or os.time() < vet.vaccineexpire)
-- CORRECTO:
if vet.isvaccinated and vet.vaccineexpire and os.time() < vet.vaccineexpire
```

**Archivo:** `server/core/callbacks.lua` linea 148
```lua
-- INCORRECTO: Compara si ambos tienen el MISMO estado breedable
candidateData.veterinary.breedable == petData.veterinary.breedable
-- CORRECTO: Deberia verificar que ambos pueden reproducirse
candidateData.veterinary.breedable == true and petData.veterinary.breedable == true
```

### 2.5 Manejo incorrecto de arrays de base de datos

| Archivo | Linea | Problema |
|---------|-------|----------|
| `server/main.lua` | 110 | `Database.GetAllCompanionsActive()` retorna array, codigo accede como objeto |
| `server/systems/items.lua` | 23 | Mismo problema |
| `server/systems/xp.lua` | 23 | Mismo problema |
| `server/systems/breeding.lua` | 210 | Usa `pairs()` en lugar de `ipairs()` para array |

### 2.6 Construccion dinamica de SQL (Potencial inyeccion)
- **Archivo:** `server/systems/tracking.lua` lineas 63-65
- **Problema:** `string.format()` con nombres de tabla/columna desde Config
- **Riesgo:** Si Config es modificable, permite SQL injection

### 2.7 Datos duplicados en configuracion
- **Archivo:** `shared/stable/stables.lua` lineas 30 y 39
- **Problema:** Coordenadas identicas para establos diferentes:
  - tumbleweed: `vector3(-5584.34, -3065.37, 2.39)`
  - wapiti: `vector3(-5584.34, -3065.37, 2.39)` (DUPLICADO)
- **Impacto:** Conflicto de ubicaciones

---

## 3. PROBLEMAS DE SEVERIDAD MEDIA

### 3.1 Condiciones de carrera (Race Conditions)

| Archivo | Lineas | Variable afectada |
|---------|--------|-------------------|
| `client/games/bone.lua` | 59-162 | `buriedBoneCoords` |
| `client/games/bone.lua` | 107, 159, 171, 209, 263, 306 | `isRetrieving` |
| `client/games/fight.lua` | 126, 490, 506, 526, 551 | `isFighting` |
| `client/stable/call.lua` | 328-354 | `isFollow` |
| `server/systems/lifecycle.lua` | 303-314 | Transaccion BD (delete antes de insert) |

### 3.2 Fugas de memoria potenciales

| Archivo | Problema |
|---------|----------|
| `client/stable/npcs.lua` | `spawnedPaidPeds` no se limpia completamente en resource stop |
| `client/stable/call.lua` | `followTimers` crece infinitamente, nunca se limpia |
| `client/games/bone.lua` | `itemProps` nunca inicializado |
| `client/state.lua` | `visualState` no se limpia en cleanup |

### 3.3 Falta de validacion null/nil

| Archivo | Linea | Acceso inseguro |
|---------|-------|-----------------|
| `client/stable/rename.lua` | 40 | `companionData.info.name` sin verificar |
| `client/stable/pets.lua` | 213 | `json.decode()` sin pcall |
| `server/main.lua` | 309 | `result[1].data` sin verificar array |
| `server/systems/fight.lua` | 209 | `GetPlayerPed()` puede retornar nil |

### 3.4 Formato inconsistente de modelo hash
- **Archivo:** `shared/config/consumables.lua` lineas 201, 212
- **Problema:** `medicineModelHash = 'p_cs_syringe01x'` usa string en lugar de backtick hash
- **Contraste:** Otras entradas usan `` `p_cs_syringe01x` ``

### 3.5 Falta manejo de errores en queries BD

| Archivo | Linea |
|---------|-------|
| `server/core/validation.lua` | 36 |
| `server/systems/tracking.lua` | 68 |
| `server/systems/lifecycle.lua` | 248 |

---

## 4. PROBLEMAS DE BAJA SEVERIDAD

### 4.1 Valores hardcodeados (deberian ser configurables)

| Archivo | Linea | Valor |
|---------|-------|-------|
| `client/games/bone.lua` | 119 | Timeout 40 iteraciones |
| `client/games/bone.lua` | 285 | Distancia 2.0 |
| `client/games/fight.lua` | 523 | Duracion pelea 60000ms |
| `client/games/fight.lua` | 669 | Distancia check 50.0 |
| `client/stable/call.lua` | 266 | FOLLOW_TIME = 10000 |

### 4.2 Strings hardcodeados (deberian usar locale)

| Archivo | Linea | String |
|---------|-------|--------|
| `client/menu/menu_stable.lua` | 603 | `'Sano'` |
| `client/menu/menu_stable.lua` | 604 | `'Enfermo'` |
| `client/menu/menu_stable.lua` | 605 | `'Vacunado'` |

### 4.3 Inconsistencias de nomenclatura

| Archivo | Linea | Campo | Deberia ser |
|---------|-------|-------|-------------|
| `shared/stable/stables.lua` | 16, 25, 34 | `petcustom` | `petCustom` |
| `shared/game/games.lua` | 34 | `findespecial` | `findSpecial` |

### 4.4 Problemas de formato

| Archivo | Linea | Problema |
|---------|-------|----------|
| `shared/game/games.lua` | 77 | Falta espacio: `howAnimTime= 5000` |
| `shared/stable/shop_props.lua` | 520 | Falta espacio: `bone ='PH_HeadProp'` |

---

## 5. PROBLEMAS EN ARCHIVOS DE INSTALACION

### 5.1 fxmanifest.lua

1. **Dependencia oxmysql comentada** (linea 111)
   - `oxmysql` esta comentado pero se usa en `@oxmysql/lib/MySQL.lua`
   - No causara error pero es inconsistente

2. **Archivo xp.lua no incluido** (CRITICO)
   - `server/systems/xp.lua` existe pero no esta en `server_scripts`

### 5.2 installation/hdrp-pets.sql

1. **Sintaxis problematica** (linea 2)
   - `/* */` vacio puede causar problemas en algunos parsers SQL

2. **Tabla comentada vs activa**
   - Version activa: `pet_companion`
   - Version comentada: `pet_companions`
   - El codigo debe usar `pet_companion` consistentemente

---

## 6. RECOMENDACIONES PRIORITARIAS

### Inmediatas (Bloquean funcionamiento)
1. Agregar `'server/systems/xp.lua'` a fxmanifest.lua
2. Cambiar `MySQL.update` a `MySQL.update.await` en todos los archivos afectados
3. Cambiar `require()` a `lib.load()` en `server/systems/fight.lua`
4. Corregir coordenadas duplicadas en `shared/stable/stables.lua`

### Alta prioridad (Pueden causar crashes)
1. Definir o importar funciones faltantes en `client/stable/call.lua`
2. Corregir acceso a arrays de BD (usar `[1]` o iterar correctamente)
3. Validar `outlawstatus` antes de usar en SQL

### Media prioridad (Mejoran estabilidad)
1. Agregar validaciones null/nil en accesos a objetos
2. Implementar limpieza de tablas que crecen (followTimers, etc.)
3. Usar `pcall()` para `json.decode()` donde pueda fallar

### Baja prioridad (Mejoran calidad)
1. Mover valores hardcodeados a Config
2. Usar locale() para strings de UI
3. Estandarizar nomenclatura (camelCase)

---

*Informe generado automaticamente por revision de codigo*
