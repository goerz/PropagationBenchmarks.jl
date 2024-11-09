.PHONY: help ipynb devrepl jupyter-lab clean distclean

.DEFAULT_GOAL := help

NOTEBOOKFILES = \
    A01_01_Cheby_InPlace_Dense.ipynb

JULIA = julia


help:   ## Show this help
	@grep -E '^([a-zA-Z_-]+):.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "%-20s %s\n", $$1, $$2}'

%.ipynb : | %.jl
	JULIA_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 time jupytext --to notebook --execute "$(*).jl"
	jupyter trust "$(*).ipynb"

Manifest.toml: Project.toml
	$(JULIA)  --project=. -e 'using Pkg; Pkg.instantiate()'
	touch $@

ipynb: Manifest.toml $(NOTEBOOKFILES)  ## Create all missing .ipynb files

devrepl: Manifest.toml
	JULIA_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 $(JULIA) --project=.

jupyter-lab: Manifest.toml  ## Run a Jupyter lab server
	JULIA_NUM_THREADS=1 NUMEXPR_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 jupyter lab --no-browser


clean: ## Remove generated files
	rm -f $(NOTEBOOKFILES)

distclean: clean ## Restore clean repository state
	rm -rf .ipynb_checkpoints
	rm -rf data/*
	rm -f Manifest.toml
