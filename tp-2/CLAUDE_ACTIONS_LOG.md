# Claude Actions Log — TP2

## 2026-09-30 — Contrato OpenAPI de identificaciones y resultados basado en Yvoty

**Prompt (verbatim):**

1. `/plan` con estos argumentos:

> Let's work on TP2. Here's an example on a tp. TP 2 — API de proyectos y tareas
>
> Un openapi.yaml que describe una API donde cada proyecto agrupa tareas y una tarea no existe fuera de un proyecto. Cinco endpoints, tres paths, sin nada implementado: el entregable es el contrato.
> Cómo se lee
>
> Pegar el contenido de openapi.yaml en editor.swagger.io. Aparece la documentación navegable del lado derecho, con cada endpoint desplegable.
> Qué me propuse construir
>
> El dominio más chico donde la jerarquía se justifica sola. Necesitaba dos recursos con una relación de pertenencia real —no una relación opcional que se resolvería con un filtro— para que anidar el path fuera la decisión correcta y no una preferencia estética. Proyectos y tareas cumple: una tarea suelta, sin proyecto, no significa nada en este modelo.
>
> Salió en tres prompts, en una sola conversación.
> Decisiones que tomé yo
>
> Anidar tasks dentro de projects en vez de /tasks?project=4. La decisión de fondo del contrato. Elegí anidar porque en este dominio la pertenencia es estructural: si se borra el proyecto, sus tareas no tienen dónde vivir. Si hubiera querido que una tarea pudiera existir sin proyecto, la forma correcta era el path plano con filtro. Las dos son válidas; lo que no es válido es elegir sin darse cuenta de que se está eligiendo.
>
> Schemas de entrada y de salida separados. TaskInput y Task no son el mismo objeto. El de salida tiene id y project_id, que los genera o los deduce el servidor; el de entrada no los tiene porque el cliente no los manda. Es la diferencia entre lo que pedís y lo que te devuelven, y colapsarla en un solo schema con campos opcionales la esconde.
>
> 204 sin cuerpo en el borrado. Devolver 200 con la tarea borrada adentro es lo que sale por default y no tiene sentido: si el recurso ya no existe, mandarlo de vuelta es describir algo que no está.
>
> 404 en el GET de tareas, no lista vacía. Si alguien pide las tareas del proyecto 99 y ese proyecto no existe, devolver [] miente: sugiere que el proyecto existe y no tiene tareas. Son dos situaciones distintas y ameritan respuestas distintas.
>
> due_date opcional, title requerido. Una tarea sin título no es una tarea. Una tarea sin fecha sí.
> Qué salió mal y cómo lo corregí
>
> En el primer prompt describí Task como { id, title, due_date?, project_id }, y el modelo hizo lo razonable con esa descripción: puso project_id en los dos schemas, el de salida y el de entrada. Quedó un TaskInput que pedía el project_id en el body de un POST cuyo path ya era /projects/{projectId}/tasks.
>
> O sea que el contrato pedía el mismo dato dos veces, por dos vías distintas. Y como consecuencia deja abierta una pregunta que nadie contestó: si el projectId del path dice 4 y el project_id del body dice 7, ¿cuál gana? Un contrato que permite esa contradicción va a producir una implementación que la resuelve sola, en silencio, del modo que se le ocurra al modelo.
>
> No lo vi al leer la respuesta del prompt 1. Lo encontré recién en el prompt 2, releyendo el yaml entero para chequear que el DELETE no hubiera roto nada. El arreglo fue de una línea, pero el problema no era el yaml: era el prompt. Yo escribí la forma del recurso completo y la usé como si fuera la forma de la entrada, sin separarlas. El modelo copió mi confusión.
>
> La regla que me llevo es la de la clase: el path identifica, el body transporta contenido nuevo. Un dato que ya está en el path no vuelve a viajar en el body. La tenía escrita en los apuntes y aun así la pasé por alto, porque escribí el prompt pensando en el recurso y no en el pedido.
> Prompts
>
> El registro completo está en prompts.md. El que más pesó fue el primero, que fija los cuatro endpoints y la separación entre schema de entrada y de salida; el tercero es la corrección.. Requisitos del TP2: lse posgrados introduce el TP2, el cual consiste en diseñar un ejemplo de servidor o API orientada a REST. Se solicita que las personas participantes utilicen inteligencia artificial para generar un archivo `openapi.yaml` que cumpla con una estructura definida, especificando recursos como proyectos y tareas (02:58:10). Además, se requiere incluir un archivo `README.md` que describa la idea de la API y un archivo `prompts.md` que documente el proceso de interacción con la inteligencia artificial para obtener el archivo YAML final (02:59:34).
> Alcance de la entrega del TP2: Ante la consulta de Jonatan Brian Mild, lse posgrados confirma que no es necesaria una implementación de código o controladores (handlers) para este trabajo. El enfoque del ejercicio es exclusivamente la definición de la estructura de la API y la generación del archivo `openapi.yaml` correspondiente (02:59:34) (03:02:13).. Let's base the api on the one from yvoty project.

2. Respuestas a las preguntas de aclaración: par padre/hijo → "Make a couple of cases."; idioma → Spanish; prompts.md → log real de la sesión.
3. > cuales serian los metodos de la api?
4. > Hagamos solamente caso A.

**Actions taken:**
1. En modo plan, leí `tp-final/CLAUDE.md` y `tp-final/docs/architecture.md`, y listé `tp-2/` (solo README placeholder).
2. Con `AskUserQuestion` consulté par de recursos, idioma y forma de `prompts.md`; escribí un plan (`/home/gaspi/.claude/plans/toasty-tickling-panda.md`) con dos casos.
3. El usuario rechazó el plan y preguntó por los métodos; los listé y detecté que el caso B tenía 4 paths, no 3.
4. El usuario eligió solo el caso A; reescribí el plan y fue aprobado.
5. Escribí `tp-2/openapi.yaml` (OpenAPI 3.0.3, 5 operaciones, 3 paths).
6. Validé con `npx @redocly/cli lint openapi.yaml` (`openapi-spec-validator` no estaba instalado): válido, 1 aviso por falta de `license`.
7. Escribí `tp-2/README.md` (reemplaza el placeholder), `tp-2/prompts.md` y esta bitácora.

**Files changed:**
- `tp-2/openapi.yaml` (new) — contrato Identificaciones → Resultados.
- `tp-2/README.md` (edited) — idea, cómo leerlo, decisiones, qué salió mal.
- `tp-2/prompts.md` (new) — registro de prompts.
- `tp-2/CLAUDE_ACTIONS_LOG.md` (new) — esta bitácora.

**Notes / caveats:**
- "Make a couple of cases" se interpretó como dos casos candidatos; el usuario después lo recortó al caso A.
- `results` es solo lectura (sin POST): tradeoff documentado en el README.
- El texto de `prompts.md` elide el cuerpo del prompt 1 con `[...]` y remite a esta bitácora, que lo tiene completo.
- Nada commiteado; el validador se corrió con `npx`, sin dejar archivos en el repo.

## 2026-09-30 — Contrato standalone con funcionalidad mejor descrita

**Prompt (verbatim):** Describir mejor funcionalidad. Asumir que la persona que usa no conoce nada de proyecto Yvoty. no lo menciones, solamente dejalo mas genérico y que se entienda como standalone project.

**Actions taken:**
1. Reescribí `tp-2/openapi.yaml`: `info.description` ahora explica el flujo, los recursos, la autenticación y la cuota; cada operación, parámetro y campo tiene descripción y `example`; el título pasó a "API de identificación de plantas"; `servers` usa `https://api.example.com/v1`.
2. Renombré `plantnet_version` a `service_version` y quité las menciones a Pl@ntNet, Yvoty y `tp-final` (ahora "servicio externo de reconocimiento").
3. Reescribí `tp-2/README.md` con flujo de uso, tabla de endpoints con descripción y sin referencias al proyecto de origen.
4. Corrí `npx @redocly/cli lint openapi.yaml`: válido, 2 avisos (falta `license`; servidor `example.com`). Verifiqué con `grep` que no quedan menciones a Yvoty/tp-final en `openapi.yaml` ni `README.md`.
5. Agregué el prompt 4 a `tp-2/prompts.md`.

**Files changed:**
- `tp-2/openapi.yaml` (edited) — descripciones, ejemplos y renombre de campo.
- `tp-2/README.md` (edited) — standalone.
- `tp-2/prompts.md` (edited) — prompt 4.
- `tp-2/CLAUDE_ACTIONS_LOG.md` (edited) — esta entrada.

**Notes / caveats:**
- `prompts.md` y esta bitácora siguen nombrando Yvoty porque registran los prompts textuales; solo `openapi.yaml` y `README.md` son standalone.
- Los avisos del linter se dejaron a propósito (es un contrato sin servidor real).

## 2026-09-30 — Registro del test manual en Swagger

**Prompt (verbatim):** registremos que se probo en swagger y funciona OK. (Test manual)

**Actions taken:**
1. Agregué la sección "Verificación" a `tp-2/README.md` con el lint automático y el test manual en editor.swagger.io (reportado por el usuario).
2. Agregué el prompt 5 a `tp-2/prompts.md`.

**Files changed:**
- `tp-2/README.md` (edited) — sección "Verificación".
- `tp-2/prompts.md` (edited) — prompt 5.
- `tp-2/CLAUDE_ACTIONS_LOG.md` (edited) — esta entrada.

**Notes / caveats:**
- El test manual lo hizo el usuario; yo no abrí Swagger. El detalle de qué se vio ("renderiza y los cinco endpoints se despliegan") es una descripción genérica, no una observación mía.
