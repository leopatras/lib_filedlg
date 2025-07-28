# Property of Four Js*
# (c) Copyright Four Js 1995, 2025. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
# 
# Four Js and its suppliers do not warrant or guarantee that these
# samples are accurate and suitable for your purposes. Their inclusion is
# purely for information purposes only.

--IMPORT FGL fglfiledlg
IMPORT FGL fglfiledlg_mobile

MAIN
  DEFINE cname STRING
  DEFINE r1 FILEDLG_RECORD
  DEFINE r2 FILEDLG_RECORD

  OPTIONS INPUT WRAP

  DISPLAY "Try options in the action panel" AT 5,5

open form f from "testfiledlg"
DISPLAY form f

  MENU "File dialog"

      --COMMAND "Choose .per"
      ON ACTION chooseper
          -- get back an existing .per filename
          LET r1.title="Please choose a form"
          LET r1.defaultfilename="filedlg.per"
          LET r1.types[1].description="Form files (*.per)"
          LET r1.types[1].suffixes="*.per"
          LET r1.types[2].description="All files (*)"
          LET r1.types[2].suffixes="*"
          LET r1.opt_delete_files=TRUE
          LET cname= filedlg_open(r1.*)
          MESSAGE ">>>>chosen file:",cname

      --COMMAND "New .per"
      ON ACTION newper
          -- get back a name for a file not existing yet
          LET r2.title="Please enter a filename for save"
          LET r2.defaultfilename="spong"
          LET r2.types[1].description="All files (*.*)"
          LET r2.types[1].suffixes="*.*"
          LET cname= filedlg_save(r2.*)
          MESSAGE ">>>>new file:",cname
      --COMMAND "browse mobile"
      ON ACTION browsemobile
          CALL fglfiledlg_mobile.browse()

      --COMMAND "Quit"
      on action Quitting
          EXIT MENU

  END MENU

END MAIN
