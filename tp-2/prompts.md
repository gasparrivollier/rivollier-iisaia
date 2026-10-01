# Prompts — TP2

Registro de los prompts de la sesión, textuales, en una sola conversación con Claude Code (modo plan primero, luego implementación).

## Prompt 1 — `/plan`

Pegó el ejemplo de otro TP2 (proyectos y tareas) y los requisitos del enunciado, y pidió basar la API en Yvoty:

> Let's work on TP2. Here's an example on a tp. TP 2 — API de proyectos y tareas
>
> Un openapi.yaml que describe una API donde cada proyecto agrupa tareas y una tarea no existe fuera de un proyecto. Cinco endpoints, tres paths, sin nada implementado: el entregable es el contrato.
> [...texto completo del ejemplo (cómo se lee, decisiones, qué salió mal, prompts) y de los requisitos del TP2: `openapi.yaml`, `README.md` y `prompts.md`; sin implementación ni handlers...]
> Let's base the api on the one from yvoty project.

(El texto completo del prompt está transcripto en `CLAUDE_ACTIONS_LOG.md`.)

Resultado: Claude leyó `tp-final/CLAUDE.md` y `docs/architecture.md`, y preguntó qué par padre/hijo modelar, el idioma y cómo producir `prompts.md`. Respuestas: "Make a couple of cases.", español, log real de la sesión. Escribió un plan con dos casos.

## Prompt 2 — rechazo del plan

> cuales serian los metodos de la api?

Resultado: Claude listó los métodos de los dos casos. Al hacerlo quedó a la vista que el caso B tenía cuatro paths y no tres, error del plan.

## Prompt 3

> Hagamos solamente caso A.

Resultado: plan reducido a Identificaciones → Resultados, aprobado, y luego implementado: `openapi.yaml` (validado con `@redocly/cli lint`), este `prompts.md`, `README.md` y la bitácora.

## Prompt 4

> Describir mejor funcionalidad. Asumir que la persona que usa no conoce nada de proyecto Yvoty. no lo menciones, solamente dejalo mas genérico y que se entienda como standalone project.

Resultado: se reescribieron `openapi.yaml` (descripción general con el flujo, los recursos, auth y cuota; descripciones y ejemplos en cada operación y campo) y `README.md`, sin ninguna referencia al proyecto de origen.

## Prompt 5

> registremos que se probo en swagger y funciona OK. (Test manual)

Resultado: se agregó la sección "Verificación" al `README.md` y se registró en la bitácora.
