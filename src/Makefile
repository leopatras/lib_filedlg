ifdef windir
  WINDIR=$(windir)
endif
#generic rule to produce .42f from .per
%.42f: %.per
	fglform -M -Wall $*
#generic rule to produce .42m from .4gl
%.42m: %.4gl
	fglcomp -M -Wall $*
#generates a list of all compiled modules from the file list of 4gl sources
#example: you have a.4gl and b.4gl in the current dir, MODULES=a.42m b.42m
MODULES=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))
#generates a list of all compiled forms from the list of .per forms
FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))
all:: $(MODULES) $(FORMS)

demo: all
	fglrun testfiledlg

echo:
	echo "MODULES:$(MODULES),FORMS:$(FORMS)

gwa.build: all
	gwabuildtool --app-dir-is-pwd --main-module=testfiledlg --program-dir . -i "*.per"

gwa.run: all gwa.build
	gwasrv gwa_dist/index.html

gwa_dist.zip: gwa.build
	rm -f gwa_dist.zip
	zip -r gwa_dist.zip gwa_dist

#upload to a server location
SCP_HOST=generomobile.de
SCP_PATH=Sites/gmi/gwa_filedlg
upload: gwa_dist.zip
	scp gwa_dist.zip $(SCP_HOST):
	ssh $(SCP_HOST) unzip -o -d $(SCP_PATH) gwa_dist.zip

format:
	fglcomp -M $(FGLFLAGS) --format --fo-inplace fglfiledlg.4gl
	fglcomp -M $(FGLFLAGS) --format --fo-inplace testfiledlg.4gl

doc:
	fglcomp --build-doc fglfiledlg.4gl
	

clean:
ifdef WINDIR
	del /s *.42* >nul 2>&1
else
	rm -f *.42*
endif
