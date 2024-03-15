main:
	Rscript main.R

setup:
	make -C tools
	make -C tools install
	Rscript setup.R
