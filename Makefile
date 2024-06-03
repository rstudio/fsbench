main:
	Rscript main.R

setup:
	make -C tools
	sudo make -C tools install
	Rscript setup.R

short:
	Rscript main.R short
