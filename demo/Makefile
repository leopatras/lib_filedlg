ifdef windir
  WINDIR=$(windir)
endif
export FGLLDPATH=../src
#generic rule to produce .42f from .per
%.42f: %.per
	fglform -M -Wall $*
#generic rule to produce .42m from .4gl
%.42m: %.4gl
	fglcomp -r -M -Wall $*
#generates a list of all compiled modules from the file list of 4gl sources
#example: you have a.4gl and b.4gl in the current dir, MODULES=a.42m b.42m
MODULES=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))
#generates a list of all compiled forms from the list of .per forms
FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))
all:: $(MODULES) $(FORMS)

testfiledlg.42m: ../src/fglfiledlg.42m ../src/fglfiledlg_mobile.42m ../src/fglfiledlg.42f ../src/fglfiledlg_mobile.42f

../src/fglfiledlg.42m:
	$(MAKE) -C ../src

../src/fglfiledlg.42f:
	$(MAKE) -C ../src

../src/fglfiledlg_mobile.42m:
	$(MAKE) -C ../src

../src/fglfiledlg_mobile.42f:
	$(MAKE) -C ../src


echo:
	echo "MODULES:$(MODULES),FORMS:$(FORMS)"

run: all
	fglrun testfiledlg

clean:
ifdef WINDIR
	del /s *.42* >nul 2>&1
else
	rm -f *.42*
endif
