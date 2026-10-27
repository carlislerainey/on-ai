# Render ../carlisle-on-ai.md to ../carlisle-on-ai.pdf (via LaTeX), then make
# the landing page's images from page 1 of the PDF.
#   make -C src          build the PDF, the card, the preview, and the page count
#   make -C src pdf      just the PDF
#   make -C src tex      just the generated .tex (in ../build/)
#   make -C src clean    remove ../build/
#
# Needs pandoc and a TeX Live with latexmk. The .md is the text; this folder
# holds the formatting: template.tex (preamble), sidenotes.lua (asides and
# CTK cues), metadata.yaml (authors), apsa.bst (references). The images need
# poppler (pdftoppm, pdfinfo) and ImageMagick.

NAME  := carlisle-on-ai
ROOT  := $(abspath $(CURDIR)/..)
BUILD := $(ROOT)/build

SRCS := $(ROOT)/$(NAME).md template.tex sidenotes.lua metadata.yaml

PDF     := $(ROOT)/$(NAME).pdf
PAGE1   := $(BUILD)/page1.png
CARD    := $(ROOT)/images/$(NAME)-card.png
PREVIEW := $(ROOT)/images/$(NAME)-preview.png
INDEX   := $(ROOT)/index.html

# The card's look: the background green, and how much of page 1 shows
# before the fade starts (in card pixels; the page shows 604 in all).
GREEN := \#4A9A79
SOLID := 340

.PHONY: all pdf tex pages clean
all: $(PDF) $(CARD) $(PREVIEW) pages
pdf: $(PDF)
tex: $(BUILD)/$(NAME).tex

$(BUILD)/$(NAME).tex: $(SRCS)
	@mkdir -p $(BUILD)
	pandoc $(ROOT)/$(NAME).md --from markdown --to latex --natbib \
	  --template template.tex --metadata-file metadata.yaml \
	  --shift-heading-level-by=-1 --lua-filter sidenotes.lua \
	  --resource-path $(ROOT) -o $@

# bibtex finds apsa.bst here and .bib files in the project folder.
$(PDF): $(BUILD)/$(NAME).tex apsa.bst $(wildcard $(ROOT)/*.bib)
	cd $(BUILD) && BSTINPUTS=$(CURDIR): BIBINPUTS=$(ROOT): TEXINPUTS=$(ROOT): \
	  latexmk -pdf -bibtex -interaction=nonstopmode -halt-on-error -silent $(NAME).tex
	cp $(BUILD)/$(NAME).pdf $@

# Page 1 at 220 dpi (1870 x 2420); the crops below are in these pixels.
$(PAGE1): $(PDF)
	@mkdir -p $(BUILD)
	pdftoppm -f 1 -l 1 -r 220 -png -singlefile $< $(basename $@)

# The link card (1200 x 630): the top of page 1 on green, with rounded
# corners, fading out toward the bottom.
$(CARD): $(PAGE1)
	magick -size 1120x604 xc:black -fill white -draw "roundrectangle 0,0 1119,640 14,14" \
	  \( -size 1120x$(SOLID) xc:white -size 1120x$$((604 - $(SOLID))) gradient:white-'gray(8)' -append \) \
	  -compose Multiply -composite $(BUILD)/mask.png
	magick $< -crop 1640x900+150+175 +repage -resize 1120x -crop 1120x604+0+0 +repage \
	  -colorspace sRGB -type TrueColor \( $(BUILD)/mask.png -colorspace gray -alpha off \) \
	  -alpha off -compose CopyAlpha -composite PNG32:$(BUILD)/panel.png
	magick -size 1200x630 xc:'$(GREEN)' \
	  \( $(BUILD)/panel.png \( +clone -background black -shadow 25x10+0+4 \) +swap \
	     -background none -layers merge +repage \) \
	  -compose over -geometry +30+26 -composite -strip $@

# The landing page's preview: the top of page 1, 1200 px wide.
$(PREVIEW): $(PAGE1)
	magick $< -crop 1640x1400+150+160 +repage -resize 1200x -strip $@

# Keep the page count under the button in index.html current.
pages: $(PDF)
	@n=$$(pdfinfo $< | awk '/^Pages:/ {print $$2}'); \
	  [ "$$n" = 1 ] && label="1 page" || label="$$n pages"; \
	  sed -i '' "s|<p class=\"meta\">[0-9]* pages*</p>|<p class=\"meta\">$$label</p>|" $(INDEX); \
	  echo "index.html: $$label"

clean:
	rm -rf $(BUILD)
