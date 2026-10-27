# Build everything from the project folder; the real rules live in src/Makefile.
#   make          the PDF, the card, the preview, and the page count
#   make pdf      just the PDF
#   make clean    remove build/

.PHONY: all pdf tex pages clean
all pdf tex pages clean:
	@$(MAKE) --no-print-directory -C src $@
