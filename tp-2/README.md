# TP 2 — API de identificación de plantas

Un `openapi.yaml` que describe una API para identificar plantas a partir de fotos. El usuario sube de 1 a 5 fotos de una misma planta; el servidor las consulta a un servicio externo de reconocimiento y guarda el resultado como una **identificación**, que contiene las **especies candidatas** ordenadas por probabilidad. Cinco endpoints, tres paths, sin nada implementado: el entregable es el contrato.

## Cómo se lee

Pegar el contenido de `openapi.yaml` en [editor.swagger.io](https://editor.swagger.io). Aparece la documentación navegable a la derecha, con cada endpoint desplegable.

## Cómo se usa (flujo típico)

1. `POST /identifications` con las fotos y el órgano que muestra cada una (`leaf`, `flower`, `fruit`, `bark`, `habit`, `other`). Responde `201` con la identificación creada y su `id`.
2. `GET /identifications/{id}/results` para ver las especies candidatas, de la más a la menos probable, con puntaje de 0 a 1, familia, género y nombres comunes.
3. `GET /identifications` para ver el historial; `DELETE /identifications/{id}` para borrar una identificación y sus resultados.

## Endpoints

| Método | Path | Qué hace | Respuestas |
|---|---|---|---|
| GET | `/identifications` | Lista las identificaciones del usuario (paginada) | 200, 401 |
| POST | `/identifications` | Crea una identificación a partir de fotos | 201, 400, 401, 422, 429 |
| GET | `/identifications/{identificationId}` | Devuelve una identificación | 200, 401, 404 |
| DELETE | `/identifications/{identificationId}` | La borra con sus resultados | 204, 401, 404 |
| GET | `/identifications/{identificationId}/results` | Lista sus especies candidatas | 200, 401, 404 |

## Qué me propuse construir

El dominio más chico donde la jerarquía se justifica sola: dos recursos con una relación de pertenencia real. Una especie candidata (con su puntaje) no significa nada sin la consulta que la produjo, así que los resultados van anidados bajo la identificación y no en un `/results?identification=4`.

## Decisiones de diseño

- **Anidar `results` dentro de `identifications`.** La pertenencia es estructural: si se borra la identificación, sus resultados no tienen dónde vivir.
- **Schemas de entrada y de salida separados.** `IdentificationInput` solo lleva `images` y `organs`; `Identification` e `IdentificationResult` agregan lo que genera el servidor (`id`, `created_at`, `rank`, `score`...). `identification_id` aparece únicamente en la salida: el path identifica, el body transporta contenido nuevo.
- **204 sin cuerpo en el borrado.**
- **404 en el GET de resultados, no lista vacía.** Pedir los resultados de una identificación inexistente no es lo mismo que una identificación sin resultados.
- **`results` es solo lectura.** Los calcula el servicio externo, así que no hay `POST` sobre ese path. Es un costo asumido: el cliente no puede escribir el recurso hijo.
- **Validaciones previas y 429 con `Retry-After`.** El servicio externo tiene cuota diaria y una consulta fallida también la consume, por eso el servidor valida las fotos (cantidad, formato, tamaño, un órgano por foto) antes de enviarlas.
- **Autenticación:** JWT en `Authorization: Bearer`. Cada usuario ve solo sus identificaciones.

## Qué salió mal

- Durante el plan se exploró un segundo caso (jardines y plantas) y la tabla de métodos que presenté decía "tres paths" cuando ese caso tenía cuatro. Lo detectó la pregunta "¿cuáles serían los métodos de la API?" al revisar el plan, antes de escribir ningún yaml. Se decidió quedarse solo con este caso, que sí cumple tres paths.
- Una primera versión de las descripciones daba por sabido el contexto del proyecto del que salió el dominio. Se reescribió para que el contrato se entienda solo.
- El validador (`@redocly/cli lint`) no marca errores; solo avisa que falta `license` en `info`, y se dejó así a propósito.

## Verificación

- Validación automática con `@redocly/cli lint`: sin errores.
- Test manual: se pegó `openapi.yaml` en [editor.swagger.io](https://editor.swagger.io) y funciona OK (la documentación renderiza y los cinco endpoints se despliegan correctamente).

## Archivos

- `openapi.yaml` — el contrato.
- `prompts.md` — registro de los prompts de la sesión.
- `CLAUDE_ACTIONS_LOG.md` — bitácora de acciones.
