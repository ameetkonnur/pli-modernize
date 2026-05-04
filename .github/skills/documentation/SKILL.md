# Documentation Skill

Use this skill when generating program documentation from PL/I source code.

## Documentation Principles

1. **Accuracy first** — verify all PL/I construct descriptions against the MCP server
2. **Audience** — target developers who may not know PL/I; explain z/OS-specific concepts
3. **Structure** — use consistent sections across all program docs for easy comparison
4. **Citations** — include Language Reference Part/page for non-trivial constructs
5. **Context** — explain WHY the code does something, not just WHAT it does
6. **Messages** — reference Messages and Codes when documenting error handling or compiler diagnostics
7. **Migration notes** — flag deprecated patterns found in code using the Migration Guide
8. **LE runtime** — document Language Environment callable services (CEE*) and runtime options using the LE Programming Guide

## Extraction Checklist

When analyzing a PL/I source file, extract:

### Program Identity
- [ ] Procedure name (from `<name>: PROCEDURE OPTIONS(MAIN)`)
- [ ] Any comment block header describing purpose. Don't assume the comment block is accurate; verify against code and MCP documentation.
- [ ] Sequence numbers (column 73–80) if present

### Declarations (DCL)
- [ ] Constants (variables with `INIT` and no reassignment)
- [ ] Working variables
- [ ] Based variables and their pointers
- [ ] Structures/unions (with level numbers)
- [ ] File declarations
- [ ] Entry declarations (external interfaces)
- [ ] Label variables

### Control Flow
- [ ] Main procedure flow
- [ ] Internal procedures (nested PROCEDURE blocks)
- [ ] BEGIN blocks
- [ ] DO groups (iterative, WHILE, UNTIL)
- [ ] IF/THEN/ELSE chains
- [ ] SELECT/WHEN/OTHERWISE
- [ ] GOTO targets and sources
- [ ] ON-unit handlers

### External Interfaces
- [ ] CALL statements (with all arguments)
- [ ] FETCH/RELEASE (dynamic linking)
- [ ] %INCLUDE members
- [ ] File I/O (READ, WRITE, GET, PUT, LOCATE, DELETE, REWRITE)

### JCL (if present)
- [ ] EXEC statement (program name, procedure)
- [ ] DD statements (data set names, dispositions)
- [ ] SYSIN data
- [ ] Library references (STEPLIB, SYSLIB)

## YAML Frontmatter Template

Every documentation file must start with:

```yaml
---
program: PROGRAM_NAME
language: "PL/I (Enterprise PL/I for z/OS 6.2)"
source: pli_src/filename.pli
analyzed: YYYY-MM-DD
procedures:
  - name: MAIN_PROC
    type: external
  - name: INTERNAL_PROC
    type: internal
external_calls:
  - name: CALLED_PROG
    linkage: PL/I | ASSEMBLER
files:
  - name: FILE_NAME
    type: INPUT | OUTPUT | UPDATE
    organization: SEQUENTIAL | DIRECT | STREAM
---
```
