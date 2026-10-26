# Render ../carlisle-on-ai.md to ../carlisle-on-ai.pdf (via LaTeX).
#   make -C src          build the PDF
#   make -C src tex      just the generated .tex (in ../build/)
#   make -C src clean    remove ../build/
#
# Needs pandoc and a TeX Live with latexmk. The .md is the text; this folder
# holds the formatting: template.tex (preamble), sidenotes.lua (asides and
# CTK cues), metadata.yaml (authors), apsa.bst (references).

NAME  := carlisle-on-ai
ROOT  := $(abspath $(CURDIR)/..)
BUILD := $(ROOT)/build

SRCS := $(ROOT)/$(NAME).md template.tex sidenotes.lua metadata.yaml

.PHONY: all tex clean
all: $(ROOT)/$(NAME).pdf
tex: $(BUILD)/$(NAME).tex

$(BUILD)/$(NAME).tex: $(SRCS)
	@mkdir -p $(BUILD)
	pandoc $(ROOT)/$(NAME).md --from markdown --to latex --natbib \
	  --template template.tex --metadata-file metadata.yaml \
	  --shift-heading-level-by=-1 --lua-filter sidenotes.lua \
	  --resource-path $(ROOT) -o $@

# bibtex finds apsa.bst here and .bib files in the project folder.
$(ROOT)/$(NAME).pdf: $(BUILD)/$(NAME).tex apsa.bst $(wildcard $(ROOT)/*.bib)
	cd $(BUILD) && BSTINPUTS=$(CURDIR): BIBINPUTS=$(ROOT): TEXINPUTS=$(ROOT): \
	  latexmk -pdf -bibtex -interaction=nonstopmode -halt-on-error -silent $(NAME).tex
	cp $(BUILD)/$(NAME).pdf $@

clean:
	rm -rf $(BUILD)
