main:
	Rscript main.R

setup:
	sudo make -C tools
	Rscript setup.R
