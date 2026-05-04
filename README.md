# PL/I Analysis Workspace

A VS Code workspace for analyzing, documenting, reviewing, and generating IBM Enterprise PL/I for z/OS code — powered by GitHub Copilot agents and an MCP server backed by indexed PL/I reference documentation.

## Quick Start

1. **Open this folder** in VS Code
2. **Verify MCP connection**: The `custom-pli-mcp` server should appear in your Copilot MCP panel (check `.vscode/mcp.json`)
3. **Drop PL/I source files** into `pli_src/`
4. **Use agents** via `@agent-name` in Copilot Chat

## Agents

| Agent | Command | What It Does |
|-------|---------|--------------|
| **PLI-Documenter** | `@PLI-Documenter document this program` | Creates comprehensive program documentation with MCP-verified language references |
| **PLI-DependencyMapper** | `@PLI-DependencyMapper map all dependencies` | Scans all PL/I files and generates cross-program dependency charts (Mermaid) |
| **PLI-FlowDiagram** | `@PLI-FlowDiagram create flow for PROGNAME` | Generates control-flow diagrams showing logic, loops, branching, and calls |
| **PLI-Reviewer** | `@PLI-Reviewer review this program` | Reviews code against PL/I best practices with severity-rated findings |
| **PLI-CodeGen** | `@PLI-CodeGen create a batch file processor` | Generates new PL/I code with error handling, JCL, and companion specs |

## Folder Structure

```
pli-workspace/
├── pli_src/                        # ← Drop your PL/I source files here
├── docs/
│   ├── programs/                   # Per-program documentation (PLI-Documenter)
│   ├── dependencies/               # Cross-program dependency charts (PLI-DependencyMapper)
│   ├── flows/                      # Control-flow diagrams (PLI-FlowDiagram)
│   └── reviews/                    # Best-practice review reports (PLI-Reviewer)
├── generated/                      # New PL/I code + specs (PLI-CodeGen)
├── .github/
│   ├── copilot-instructions.md     # Workspace-level Copilot instructions
│   ├── agents/                     # Agent definitions
│   │   ├── pli-documenter.agent.md
│   │   ├── pli-dependency-mapper.agent.md
│   │   ├── pli-flow-diagram.agent.md
│   │   ├── pli-reviewer.agent.md
│   │   └── pli-codegen.agent.md
│   └── skills/                     # Reusable skills
│       ├── pli-language/SKILL.md   # PL/I language reference lookup patterns
│       ├── documentation/SKILL.md  # Documentation extraction checklist
│       ├── diagrams/SKILL.md       # Mermaid diagram conventions
│       ├── review/SKILL.md         # Best practices checklist & anti-patterns
│       └── codegen/SKILL.md        # Code templates & JCL patterns
└── .vscode/
    └── mcp.json                    # MCP server config (custom-pli-mcp)
```

## MCP Server

The `custom-pli-mcp` server provides semantic search and page-level fetch across indexed IBM documentation:

| Document | Coverage |
|----------|----------|
| Enterprise PL/I for z/OS 6.2 Language Reference | Parts 1–4 (766 pages) |
| Enterprise PL/I for z/OS 6.2 Programming Guide | Parts 1–3 (562 pages) |

**Tools:**
- `search` — semantic search across all indexed PDFs
- `fetch` — retrieve full page content by document title and page number

All agents use these tools to verify PL/I syntax, look up built-in functions, and confirm best practices.

## Example Workflows

### Document a single program
```
@PLI-Documenter Analyze pli_src/CRTPLN3.pli and create documentation
```

### Map dependencies across all programs
```
@PLI-DependencyMapper Scan all files in pli_src/ and create a dependency analysis
```

### Visualize program logic
```
@PLI-FlowDiagram Create a control-flow diagram for pli_src/CRTPLN3.pli
```

### Review code quality
```
@PLI-Reviewer Review pli_src/CRTPLN3.pli against best practices
```

### Generate new PL/I code
```
@PLI-CodeGen Create a PL/I program that reads a VSAM KSDS, 
validates each record against business rules, writes valid records 
to an output sequential file, and logs errors to SYSPRINT
```

### Chain agents
```
1. @PLI-Documenter document pli_src/CRTPLN3.pli
2. @PLI-Reviewer review pli_src/CRTPLN3.pli
3. @PLI-CodeGen generate a fixed version addressing the review findings
```

## Adding More Reference PDFs

To expand the MCP server's knowledge (e.g., add z/OS MVS Assembler Services Guide):

1. Split large PDFs into ≤250-page chunks using `split-pdf.py` (in the mymcp repo)
2. Upload to the Azure Blob Storage container backing the MCP server
3. Run the search pipeline indexer to index the new documents
4. The `search` and `fetch` tools will automatically include the new content
