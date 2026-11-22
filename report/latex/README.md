# Report (LaTeX sources)

LaTeX sources of the project report, in Italian.
The compiled report is in the folder above (`report/`).

## Folders

```
latex/
├── main.tex        preamble and list of sections
├── front.tex       front page
├── sections/       one .tex file for each section
├── figures/        figures of the report (PDF) and simulation screenshots (PNG)
├── img/            logo for the front page
├── Makefile
└── install_dependencies.sh
```

The figures were drawn with draw.io and exported as PDF.
The same figures, as SVG, are in the `figures/` folder at the root of the repository.

## Requirements

- **TeX Live** (or MacTeX), with the Italian language package
- `latexmk`

The script `install_dependencies.sh` installs everything on Debian/Ubuntu:

```bash
chmod +x install_dependencies.sh
./install_dependencies.sh
```

## Usage

Compile the document once (the output is `main.pdf`):
```bash
make compile
```

Watch mode: opens the PDF in Evince and compiles again when a file changes:
```bash
make watch
```

Remove the temporary LaTeX files (keeps the PDF):
```bash
make clean
```

Remove all the generated files, PDF included:
```bash
make cleanall
```
