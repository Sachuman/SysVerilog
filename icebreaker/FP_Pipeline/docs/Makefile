
assignment.pdf: main.md
	pandoc \
	 --from=markdown \
	 --to=latex \
	 --toc \
	 --shift-heading-level-by -1 \
	 --number-sections \
	 --from=markdown+fancy_lists \
	 -o $@ \
	 $<

clean:
	rm -f assignment.pdf
