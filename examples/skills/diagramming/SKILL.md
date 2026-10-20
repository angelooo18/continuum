---
name: diagramming
description: Diagram source and rendering conventions for Mermaid, Graphviz, and simple architecture sketches. Use when explaining flows, dependencies, state machines, or architecture visually.
---

# Diagramming

1. Choose the smallest diagram that answers the question.
2. Prefer Mermaid for flows, sequence diagrams, and architecture.
3. Prefer Graphviz for dense graphs and dependency networks.
4. Write the source file first:
   - `diagrams/<name>.mmd`
   - `diagrams/<name>.dot`
5. Render to SVG when possible:
   - `mmdc -i diagrams/<name>.mmd -o diagrams/<name>.svg`
   - `dot -Tsvg diagrams/<name>.dot -o diagrams/<name>.svg`
6. If the renderer is unavailable, return the source and the exact render command.
7. Do not invent nodes or edges that are not supported by the source material.
8. Return the output path, a one-line description, and any limitation.
