# Diagrams Skill

Use this skill when generating Mermaid diagrams for PL/I program analysis.

## Mermaid Diagram Types

### 1. Control-Flow Diagrams (`flowchart TD`)

For visualizing program logic within a single program.

```mermaid
flowchart TD
    START([PROGNAME: PROC OPTIONS MAIN]) --> DECL[Declare variables]
    DECL --> INIT[Initialize]
    INIT --> CHECK{Condition?}
    CHECK -->|Yes| PROCESS[Process data]
    CHECK -->|No| SKIP[Skip]
    PROCESS --> LOOP{More data?}
    LOOP -->|Yes| PROCESS
    LOOP -->|No| CLEANUP[Cleanup]
    SKIP --> CLEANUP
    CLEANUP --> END_PROC([END PROGNAME])
```

### 2. Dependency Diagrams (`graph TD`)

For visualizing relationships across programs.

```mermaid
graph TD
    subgraph "Batch Job STEP1"
        PROG_A[PROG_A]
        PROG_B[PROG_B]
    end
    subgraph "System Services"
        SVC1["SYS1.CSSLIB: CSRIDAC"]
        SVC2["SYS1.CSSLIB: CSRVIEW"]
    end
    subgraph "Data Sets"
        DS1[(MASTER.FILE)]
        DS2[(TRANS.FILE)]
    end
    PROG_A -->|CALL| PROG_B
    PROG_A -->|CALL| SVC1
    PROG_B -->|CALL| SVC2
    PROG_A ---|READ| DS1
    PROG_B ---|WRITE| DS2
```

### 3. Sequence Diagrams (`sequenceDiagram`)

For visualizing the order of operations and external calls.

```mermaid
sequenceDiagram
    participant P as Program
    participant S as System Service
    participant F as File/Dataset

    P->>S: CALL CSRIDAC('BEGIN', ...)
    S-->>P: RETURN_CODE, OBJECT_ID
    P->>F: ALLOCATE buffer
    P->>S: CALL CSRVIEW('BEGIN', ...)
    S-->>P: RETURN_CODE
    P->>P: Process data in window
    P->>S: CALL CSRSCOT(save)
    S-->>P: RETURN_CODE
    P->>S: CALL CSRVIEW('END', ...)
    P->>S: CALL CSRIDAC('END', ...)
    P->>F: FREE buffer
```

## Node Naming Conventions

| PL/I Element | Node Format | Example |
|-------------|-------------|---------|
| Procedure entry | `([NAME: PROC])` | `([CRTPLN3: PROC OPTIONS MAIN])` |
| Procedure exit | `([END NAME])` | `([END CRTPLN3])` |
| Assignment/computation | `[description]` | `[Calculate page boundary]` |
| Decision (IF) | `{condition}` | `{ORIG ¬= 0?}` |
| External CALL | `[[PROC_NAME]]` | `[[CSRIDAC]]` |
| File I/O | `[(operation)]` | `[(READ MASTER)]` |
| Loop start | `{loop condition}` | `{I <= NUM_WIN_ELEM?}` |
| ON-unit handler | `>condition]` | `>ENDFILE]` |
| ALLOCATE/FREE | `[ALLOC/FREE var]` | `[ALLOC S]` |

## Styling

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#e1f5fe', 'primaryTextColor': '#01579b', 'primaryBorderColor': '#0288d1', 'lineColor': '#0288d1', 'secondaryColor': '#fff3e0', 'tertiaryColor': '#f3e5f5'}}}%%
```

### Class Definitions for Color-Coding
```
classDef entryExit fill:#c8e6c9,stroke:#2e7d32,color:#1b5e20
classDef decision fill:#fff9c4,stroke:#f9a825,color:#f57f17
classDef io fill:#e1f5fe,stroke:#0288d1,color:#01579b
classDef error fill:#ffcdd2,stroke:#c62828,color:#b71c1c
classDef external fill:#f3e5f5,stroke:#7b1fa2,color:#4a148c
```

## Complexity Guidelines

- **< 10 statements**: Single flowchart
- **10–30 statements**: High-level + one detailed flowchart
- **30–100 statements**: High-level + per-section detailed flowcharts
- **> 100 statements**: High-level + per-procedure flowcharts + sequence diagram for external calls
