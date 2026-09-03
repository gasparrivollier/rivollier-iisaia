# TP-1 — Formulario de Reclamos del Subte

Un front-end en HTML/CSS/JS plano para presentar un reclamo sobre el servicio del Subte de Buenos Aires.

## Sobre este trabajo práctico

Este TP es un ejercicio de UI/UX: primero construir un formulario funcional, y luego (en una etapa posterior) hacerlo deliberadamente difícil de usar para estudiar heurísticas de usabilidad y anti-patrones. Por ahora el formulario está pensado para ser **correcto y directo** — todavía sin fricción intencional.

## Stack

- Un único archivo HTML autocontenido (markup, CSS en `<style>`, y JS vanilla en `<script>`). Sin framework, sin build step, sin backend.
- Los envíos del formulario se simulan del lado del cliente (ver `tp-1/CLAUDE.md` para más detalles), ya que este TP no tiene servidor.
- El logo del Subte en el encabezado se carga en vivo desde Wikimedia Commons — la única dependencia de red que tiene la página.

## Cómo correrlo

Abrí `index.html` directamente en un navegador (doble clic, o vía `file://`), o serví la carpeta con cualquier servidor de archivos estático, por ejemplo:

```
python3 -m http.server -d tp-1 8000
```

Después visitá `http://localhost:8000`. Se necesita conexión a internet para que cargue el logo del encabezado.

## Estructura

- `index.html` — el formulario de reclamos: markup, estilos y comportamiento, todo en un solo archivo. No hay otros archivos del proyecto.

Ver `tp-1/CLAUDE.md` para notas de arquitectura y convenciones específicas de este TP.
